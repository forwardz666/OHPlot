// OHPlot Menu Bar Component
// Implements precise menu interaction logic:
// - onClick: toggle current menu open/close
// - onHover: switch to current menu only if another menu is already open
// - second-level (cascade) submenus open to the RIGHT of the parent row as a
//   floating panel (Windows SciDAVis behavior), with hover + click support
// - every row shows hover/press feedback (white -> light gray #E8E8E8)
// - panel width auto-fits the longest item text (label + shortcut + icon)
import hilog from '@ohos.hilog';
import display from '@ohos.display';
import * as Theme from './Theme';
import { MeasureText } from '@kit.ArkUI';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

// ── Menu layout constants (vp) ──────────────────────────────────────────────
const ROW_HEIGHT: number = Theme.H_MENU;  // 28: level-1 row height
const CHILD_ROW_HEIGHT: number = 26;      // level-2 row height
const SEPARATOR_HEIGHT: number = 5;       // 1px line + 2+2 margins
// 图标左侧留白（2026-08-04 从24减小消除图标前白空）
const PAD_LEFT: number = 6;
const PAD_RIGHT: number = 12;
// Fixed icon column reserved on EVERY row (Windows SciDAVis two-column
// layout): rows without an icon keep an empty slot of the same width, so all
// labels start at the identical x.  16vp icon + 8vp gap.
const ICON_COLUMN_WIDTH: number = 24;
const ICON_SIZE: number = 16;
const ICON_GAP: number = 8;
const SHORTCUT_GAP: number = 20;
// ▸ arrow allowance for parent rows that open a child panel (so the panel is
// wide enough that the arrow does not squeeze the label).
const PARENT_ARROW_WIDTH: number = 12;
// Flat safety buffer added to the final panel width so the longest label
// never wraps (guards sub-pixel rounding / font fallback / residual CJK
// under-measurement).
const SAFETY_BUFFER_VP: number = 8;
// CJK glyphs (HarmonyOS Sans) render wider than MeasureText reports: inflate
// the measured width by this many vp per CJK char.
const CJK_EXTRA_PER_CHAR_VP: number = 2.5;
const CJK_CHAR_RE: RegExp = /[\u4e00-\u9fff\u3400-\u4dbf\u3040-\u30ff]/;
const HOVER_BG: string = '#E8E8E8';

interface SubMenuItemData {
  id: string;
  label: string;
  shortcut?: string;
  // Menu-state flags driven by getUiState (undo/redo, window list...):
  // enabled=false renders grey and swallows the tap; checked=true shows ✓.
  enabled?: boolean;
  checked?: boolean;
  // Left-side icon (Agent C adds $r('app.media.mn_xxx') values to the menu
  // data).  Rendered 16x16 to the left of the label.
  icon?: ResourceStr;
  // Nested submenu children (second-level popup).  When present, the item
  // renders as a group header with a ▸ arrow; hovering/clicking opens a child
  // popup to the RIGHT of the row.
  children?: SubMenuItemData[];
}

interface MenuItemData {
  id: string;
  label: string;
  items?: SubMenuItemData[];
}

// Measure a single-line text width in vp.  MeasureText.measureText() returns
// px; convert via the display density (vp = px / densityPixels).
// The fontFamily is pinned to 'HarmonyOS Sans' (the default family) so the
// measurement matches the actual Text rendering, and CJK glyphs get a
// per-char inflation because MeasureText under-reports their advance width.
function textWidthVp(text: string, fontSize: number): number {
  const widthPx: number = MeasureText.measureText({
    textContent: text,
    fontSize: fontSize,
    fontFamily: 'HarmonyOS Sans'
  });
  let widthVp: number = widthPx / display.getDefaultDisplaySync().densityPixels;
  let cjkCount: number = 0;
  for (let i: number = 0; i < text.length; i++) {
    if (CJK_CHAR_RE.test(text.charAt(i))) {
      cjkCount++;
    }
  }
  if (cjkCount > 0) {
    widthVp += cjkCount * CJK_EXTRA_PER_CHAR_VP;
  }
  return widthVp;
}

// Auto-fit panel width: widest item (fixed icon column + label + optional
// shortcut + optional ▸ arrow) plus horizontal paddings and a flat safety
// buffer.  The icon column is reserved UNCONDITIONALLY (two-column layout) so
// every row — with or without an icon — shares the same label x.
function computePanelWidthVp(items: SubMenuItemData[] | undefined, labelFs: number, shortcutFs: number): number {
  if (items === undefined) {
    return 160;
  }
  let maxTextVp: number = 0;
  for (const item of items) {
    if (item.id.startsWith('sep')) {
      continue;
    }
    let w: number = ICON_COLUMN_WIDTH;
    w += textWidthVp(item.checked === true ? '✓ ' + item.label : item.label, labelFs);
    if (item.shortcut !== undefined && item.shortcut !== '') {
      w += SHORTCUT_GAP + textWidthVp(item.shortcut, shortcutFs);
    }
    if (item.children !== undefined && item.children.length > 0) {
      w += PARENT_ARROW_WIDTH;
    }
    if (w > maxTextVp) {
      maxTextVp = w;
    }
  }
  return maxTextVp + PAD_LEFT + PAD_RIGHT + SAFETY_BUFFER_VP;
}

// Accumulate the parent row's top offset within the level-1 column so the
// second-level panel can be positioned exactly beside it (deterministic; no
// async onAreaChange round-trip needed).
function computeParentRowYVp(items: SubMenuItemData[], targetId: string): number {
  let y: number = 0;
  for (const item of items) {
    if (item.id === targetId) {
      break;
    }
    y += item.id.startsWith('sep') ? SEPARATOR_HEIGHT : ROW_HEIGHT;
  }
  return y;
}

@Component
export struct MenuBar {
  @Link openMenu: string | null;
  // @Prop (deep copy) so the bar re-renders when the parent rebuilds the
  // menu model from getUiState (dynamic window list, undo/redo greying).
  @Prop menus: MenuItemData[] = [];
  onItemClick?: (itemId: string) => void;
  // Reports each menu title's x offset (vp) so the parent can anchor the
  // floating dropdown under its title (the dropdown lives in the parent
  // Stack, NOT in this Column, to avoid pushing the content area down).
  onAnchorChange?: (menuId: string, x: number) => void;
  // Hover/press feedback for the top titles (light gray, Windows-style).
  @State hoverTitle: string = '';
  @State pressedTitle: string = '';

  private titleHighlighted(menuId: string): boolean {
    return this.hoverTitle === menuId || this.pressedTitle === menuId || this.openMenu === menuId;
  }

  build() {
    Column() {
      Row() {
        ForEach(this.menus, (menu: MenuItemData) => {
          Text(menu.label)
            .fontSize(Theme.FS_MENU)
            .fontColor(this.openMenu === menu.id ? Theme.TEXT_ACTIVE : Theme.TEXT)
            .backgroundColor(this.titleHighlighted(menu.id) ? HOVER_BG : Color.Transparent)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .onAreaChange((_old: Area, area: Area) => {
              if (this.onAnchorChange) {
                this.onAnchorChange(menu.id, Number(area.position.x));
              }
            })
            .onClick(() => {
              this.openMenu = this.openMenu === menu.id ? null : menu.id;
            })
            .onHover((isHover: boolean) => {
              this.hoverTitle = isHover ? menu.id : '';
              if (isHover && this.openMenu !== null && this.openMenu !== menu.id) {
                this.openMenu = menu.id;
              }
            })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.pressedTitle = menu.id;
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.pressedTitle = '';
              }
            })
        })
        // Blank filler: closes an open menu when the empty menu-bar area is
        // tapped.  NOTE: this must NOT be an onTouch on the whole Row — that
        // fires before the menu Texts' onClick and breaks the toggle (the
        // menu would always reopen instead of closing).
        Blank()
          .onClick(() => {
            if (this.openMenu !== null) {
              this.openMenu = null;
            }
          })
      }
      .width('100%')
      .height(Theme.H_MENU)
      .backgroundColor(Theme.CHROME_BG)
      .padding({ left: 2 })
      .border({ width: { bottom: 1 }, color: Theme.LINE })
    }
    .alignItems(HorizontalAlign.Start)
  }
}

// Floating dropdown panel.  The PARENT Stack renders it above the content
// area and positions it with .position() so opening a menu does not reflow
// the layout underneath.  The panel width auto-fits the longest item text.
@Component
export struct DropdownMenu {
  @Link openMenu: string | null;
  @Prop menus: MenuItemData[] = [];
  onItemClick?: (itemId: string) => void;

  private findOpenMenu(): MenuItemData | undefined {
    for (const menu of this.menus) {
      if (menu.id === this.openMenu) {
        return menu;
      }
    }
    return undefined;
  }

  private panelWidthVp(): number {
    const menu: MenuItemData | undefined = this.findOpenMenu();
    return computePanelWidthVp(menu === undefined ? undefined : menu.items, Theme.FS_MENU, 12);
  }

  build() {
    if (this.openMenu !== null) {
      Column() {
        SubMenuItems({ openMenu: $openMenu, menus: this.menus, onItemClick: this.onItemClick })
      }
      .width(this.panelWidthVp())
      .backgroundColor('#FFFFFF')
      .border({ width: 1, color: Theme.LINE })
      .shadow({ radius: 6, color: '#40000000', offsetX: 2, offsetY: 2 })
    }
  }
}

@Component
struct SubMenuItems {
  @Link openMenu: string | null;
  @Prop menus: MenuItemData[] = [];
  onItemClick?: (itemId: string) => void;
  // Which level-1 parent has its second-level panel open (by id).
  @State openSubId: string = '';
  // Row hover/press feedback (white -> light gray) for mouse + touch.
  @State hoveredId: string = '';
  @State pressedId: string = '';
  // True while the pointer is over the floating child panel, so a parent
  // row's hover-exit does not close the cascade while the pointer travels
  // between the parent row and its child panel.
  @State childPanelHovered: boolean = false;
  // Panel origin (vp) captured from onAreaChange, used to keep the floating
  // child panel inside the screen bounds.
  @State panelGlobalX: number = 0;
  @State panelGlobalY: number = 0;
  private closeTimer: number = -1;

  // ── interaction helpers ────────────────────────────────────────────────────

  private handleRowTouch(event: TouchEvent, id: string): void {
    if (event.type === TouchType.Down) {
      this.pressedId = id;
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.pressedId = '';
    }
  }

  // Deferred close: only close the cascade if the pointer is neither over the
  // child panel nor over any menu row (avoids flicker while the pointer moves
  // from a parent row into its child panel).
  private scheduleCloseSubmenu(): void {
    if (this.closeTimer !== -1) {
      clearTimeout(this.closeTimer);
    }
    this.closeTimer = setTimeout(() => {
      this.closeTimer = -1;
      if (this.openSubId !== '' && !this.childPanelHovered && this.hoveredId === '') {
        this.openSubId = '';
      }
    }, 80);
  }

  private childItems(items: SubMenuItemData[] | undefined): SubMenuItemData[] | undefined {
    if (items === undefined) {
      return undefined;
    }
    for (const item of items) {
      if (item.id === this.openSubId && item.children) {
        return item.children;
      }
    }
    return undefined;
  }

  private childPanelWidthVp(items: SubMenuItemData[] | undefined): number {
    return computePanelWidthVp(this.childItems(items), 13, 11);
  }

  private childPanelHeightVp(children: SubMenuItemData[] | undefined): number {
    if (children === undefined) {
      return 0;
    }
    let h: number = 0;
    for (const child of children) {
      h += child.id.startsWith('sep') ? SEPARATOR_HEIGHT : CHILD_ROW_HEIGHT;
    }
    return h;
  }

  private childPanelPosition(items: SubMenuItemData[] | undefined): Position {
    const parentPanelW: number = computePanelWidthVp(items, Theme.FS_MENU, 12);
    const children: SubMenuItemData[] | undefined = this.childItems(items);
    const childW: number = computePanelWidthVp(children, 13, 11);
    const childH: number = this.childPanelHeightVp(children);
    const parentRowY: number = items === undefined ? 0 : computeParentRowYVp(items, this.openSubId);
    const winW: number = display.getDefaultDisplaySync().width / display.getDefaultDisplaySync().densityPixels;
    const winH: number = display.getDefaultDisplaySync().height / display.getDefaultDisplaySync().densityPixels;
    let x: number = parentPanelW;
    let y: number = parentRowY;
    // Flip to the LEFT when the panel would cross the right screen edge.
    if (this.panelGlobalX + parentPanelW + childW > winW) {
      x = -childW;
    }
    // Shift up when the panel would cross the bottom screen edge.
    if (this.panelGlobalY + parentRowY + childH > winH) {
      const overflow: number = this.panelGlobalY + parentRowY + childH - winH;
      y = overflow > parentRowY ? 0 : parentRowY - overflow;
    }
    return { x: x, y: y };
  }

  // ── row builders ───────────────────────────────────────────────────────────

  @Builder
  NormalRow(subItem: SubMenuItemData) {
    Row() {
      // Fixed-width icon column (two-column layout).  The slot is exactly
      // ICON_SIZE(16) + ICON_GAP(8) = ICON_COLUMN_WIDTH(24) total: both
      // branches render inside the SAME fixed-width wrapper Row (16vp wide), so
      // every row — with or without an icon — reserves exactly the same space
      // and all labels start at the identical x.  The icon-less branch holds a
      // real (invisible) Text so the wrapper cannot collapse to zero width.
      Row() {
        if (subItem.icon !== undefined) {
          Image(subItem.icon)
            .width(ICON_SIZE)
            .height(ICON_SIZE)
            .objectFit(ImageFit.Contain)
        } else {
          Text('·')
            .width(ICON_SIZE)
            .height(ICON_SIZE)
            .fontSize(1)
            .fontColor(Color.Transparent)
            .visibility(Visibility.Hidden)
        }
      }
      .width(ICON_SIZE)
      .height(ICON_SIZE)
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .margin({ right: ICON_GAP })
      Text(subItem.checked === true ? '✓ ' + subItem.label : subItem.label)
        .fontSize(Theme.FS_MENU)
        .fontColor(subItem.enabled === false ? Theme.TEXT_DISABLED : Theme.TEXT_ACTIVE)
        .layoutWeight(1)
        .textAlign(TextAlign.Start)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (subItem.shortcut) {
        Text(subItem.shortcut)
          .fontSize(12)
          .fontColor(subItem.enabled === false ? '#C8C8C8' : '#888888')
          .margin({ left: SHORTCUT_GAP })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .height(ROW_HEIGHT)
    .padding({ left: PAD_LEFT, right: PAD_RIGHT })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.hoveredId === subItem.id || this.pressedId === subItem.id ? HOVER_BG : Color.Transparent)
    .onHover((hover: boolean) => {
      if (hover) {
        hilog.info(DOMAIN, TAG, 'submenu hover: %{public}s', subItem.id);
        this.hoveredId = subItem.id;
        // Hovering a non-parent item closes any open cascade.
        if (this.openSubId !== '') {
          this.openSubId = '';
        }
      } else {
        if (this.hoveredId === subItem.id) {
          this.hoveredId = '';
        }
      }
    })
    .onTouch((event: TouchEvent) => {
      this.handleRowTouch(event, subItem.id);
    })
    .onClick(() => {
      if (subItem.enabled === false) {
        hilog.info(DOMAIN, TAG, 'submenu click ignored (disabled): %{public}s', subItem.id);
        return; // greyed item: keep the menu open, do nothing
      }
      hilog.info(DOMAIN, TAG, 'submenu click: %{public}s', subItem.id);
      if (this.onItemClick) {
        this.onItemClick(subItem.id);
      }
      this.openMenu = null;
    })
  }

  @Builder
  ParentRow(subItem: SubMenuItemData) {
    Row() {
      // Fixed-width icon column (two-column layout).  The slot is exactly
      // ICON_SIZE(16) + ICON_GAP(8) = ICON_COLUMN_WIDTH(24) total: both
      // branches render inside the SAME fixed-width wrapper Row (16vp wide), so
      // every row — with or without an icon — reserves exactly the same space
      // and all labels start at the identical x.  The icon-less branch holds a
      // real (invisible) Text so the wrapper cannot collapse to zero width.
      Row() {
        if (subItem.icon !== undefined) {
          Image(subItem.icon)
            .width(ICON_SIZE)
            .height(ICON_SIZE)
            .objectFit(ImageFit.Contain)
        } else {
          Text('·')
            .width(ICON_SIZE)
            .height(ICON_SIZE)
            .fontSize(1)
            .fontColor(Color.Transparent)
            .visibility(Visibility.Hidden)
        }
      }
      .width(ICON_SIZE)
      .height(ICON_SIZE)
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .margin({ right: ICON_GAP })
      Text(subItem.label)
        .fontSize(Theme.FS_MENU)
        .fontColor(subItem.enabled === false ? Theme.TEXT_DISABLED : Theme.TEXT_ACTIVE)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text('▸')
        .fontSize(12)
        .fontColor(subItem.enabled === false ? '#C8C8C8' : '#666666')
        .maxLines(1)
    }
    .width('100%')
    .height(ROW_HEIGHT)
    .padding({ left: PAD_LEFT, right: PAD_RIGHT })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.openSubId === subItem.id || this.hoveredId === subItem.id || this.pressedId === subItem.id
      ? HOVER_BG : Color.Transparent)
    .onHover((hover: boolean) => {
      if (hover) {
        if (subItem.enabled !== false) {
          this.openSubId = subItem.id;
        }
        this.hoveredId = subItem.id;
      } else {
        if (this.hoveredId === subItem.id) {
          this.hoveredId = '';
        }
        this.scheduleCloseSubmenu();
      }
    })
    .onTouch((event: TouchEvent) => {
      this.handleRowTouch(event, subItem.id);
    })
    .onClick(() => {
      if (subItem.enabled === false) { return; }
      // Toggle nested popup on click (touch devices)
      this.openSubId = this.openSubId === subItem.id ? '' : subItem.id;
    })
  }

  @Builder
  PasteRow(subItem: SubMenuItemData) {
    Row() {
      // Security component: clicking grants a one-shot temporary
      // READ_PASTEBOARD authorization (the full ACL permission is not
      // grantable with the debug signing profile).  Rendered ICON-ONLY — the
      // security component cannot show arbitrary text — so the localized
      // label (subItem.label from the menu data) is drawn as a normal Text
      // beside it.
      PasteButton({ icon: PasteIconStyle.LINES, buttonType: ButtonType.Normal })
        .iconSize(16)
        .iconColor('#000000')
        .backgroundColor('#FFFFFF')
        .padding({ left: 0, right: 0, top: 4, bottom: 4 })
        .onClick((_event: ClickEvent, result: PasteButtonOnClickResult) => {
          hilog.info(DOMAIN, TAG, 'PasteButton click result: %{public}d', result);
          if (result === PasteButtonOnClickResult.SUCCESS && this.onItemClick) {
            this.onItemClick(subItem.id);
          }
          this.openMenu = null;
        })
      Text(subItem.label)
        .fontSize(Theme.FS_MENU)
        .fontColor(Theme.TEXT_ACTIVE)
        .layoutWeight(1)
        .textAlign(TextAlign.Start)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: ICON_GAP })
      if (subItem.shortcut) {
        Text(subItem.shortcut)
          .fontSize(12)
          .fontColor('#888888')
          .margin({ left: SHORTCUT_GAP })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .height(ROW_HEIGHT)
    .padding({ left: PAD_LEFT, right: PAD_RIGHT })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.hoveredId === subItem.id || this.pressedId === subItem.id ? HOVER_BG : Color.Transparent)
    .onHover((hover: boolean) => {
      if (hover) {
        this.hoveredId = subItem.id;
        if (this.openSubId !== '') {
          this.openSubId = '';
        }
      } else {
        if (this.hoveredId === subItem.id) {
          this.hoveredId = '';
        }
      }
    })
    .onTouch((event: TouchEvent) => {
      this.handleRowTouch(event, subItem.id);
    })
  }

  @Builder
  ChildRow(child: SubMenuItemData) {
    Row() {
      // Fixed-width icon column (two-column layout).  The slot is exactly
      // ICON_SIZE(16) + ICON_GAP(8) = ICON_COLUMN_WIDTH(24) total: both
      // branches render inside the SAME fixed-width wrapper Row (16vp wide), so
      // every row — with or without an icon — reserves exactly the same space
      // and all labels start at the identical x.  The icon-less branch holds a
      // real (invisible) Text so the wrapper cannot collapse to zero width.
      Row() {
        if (child.icon !== undefined) {
          Image(child.icon)
            .width(ICON_SIZE)
            .height(ICON_SIZE)
            .objectFit(ImageFit.Contain)
        } else {
          Text('·')
            .width(ICON_SIZE)
            .height(ICON_SIZE)
            .fontSize(1)
            .fontColor(Color.Transparent)
            .visibility(Visibility.Hidden)
        }
      }
      .width(ICON_SIZE)
      .height(ICON_SIZE)
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .margin({ right: ICON_GAP })
      Text(child.checked === true ? '✓ ' + child.label : child.label)
        .fontSize(13)
        .fontColor(child.enabled === false ? Theme.TEXT_DISABLED : Theme.TEXT_ACTIVE)
        .layoutWeight(1)
        .textAlign(TextAlign.Start)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (child.shortcut) {
        Text(child.shortcut)
          .fontSize(11)
          .fontColor(child.enabled === false ? '#C8C8C8' : '#888888')
          .margin({ left: SHORTCUT_GAP })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .height(CHILD_ROW_HEIGHT)
    .padding({ left: PAD_LEFT, right: PAD_RIGHT })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.hoveredId === child.id || this.pressedId === child.id ? HOVER_BG : Color.Transparent)
    .onHover((hover: boolean) => {
      if (hover) {
        this.hoveredId = child.id;
      } else {
        if (this.hoveredId === child.id) {
          this.hoveredId = '';
        }
      }
    })
    .onTouch((event: TouchEvent) => {
      this.handleRowTouch(event, child.id);
    })
    .onClick(() => {
      if (child.enabled === false) {
        hilog.info(DOMAIN, TAG, 'nested submenu click ignored (disabled): %{public}s', child.id);
        return;
      }
      hilog.info(DOMAIN, TAG, 'nested submenu click: %{public}s', child.id);
      if (this.onItemClick) {
        this.onItemClick(child.id);
      }
      this.openMenu = null;
      this.openSubId = '';
    })
  }

  // ── build ──────────────────────────────────────────────────────────────────

  build() {
    ForEach(this.menus, (menu: MenuItemData) => {
      if (this.openMenu === menu.id) {
        Stack({ alignContent: Alignment.TopStart }) {
          // Level-1 column (the menu panel itself).
          Column() {
            ForEach(menu.items || [], (subItem: SubMenuItemData) => {
              if (subItem.id.startsWith('sep')) {
                // Separator line
                Row()
                  .width('100%')
                  .height(1)
                  .backgroundColor('#E0E0E0')
                  .margin({ top: 2, bottom: 2 })
              } else if (subItem.id === 'paste' && subItem.enabled !== false) {
                this.PasteRow(subItem)
              } else if (subItem.children && subItem.children.length > 0) {
                this.ParentRow(subItem)
              } else {
                this.NormalRow(subItem)
              }
            }, (subItem: SubMenuItemData) => subItem.id)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          // Second-level floating panel, positioned to the RIGHT of the
          // parent row (Windows-style cascade).  Out of the Column's layout
          // flow, so it overlays the content area without reflowing.
          if (this.openSubId !== '') {
            Column() {
              ForEach(this.childItems(menu.items) || [], (child: SubMenuItemData) => {
                if (child.id.startsWith('sep')) {
                  Row()
                    .width('100%')
                    .height(1)
                    .backgroundColor('#E0E0E0')
                    .margin({ top: 1, bottom: 1 })
                } else {
                  this.ChildRow(child)
                }
              }, (child: SubMenuItemData) => child.id)
            }
            .width(this.childPanelWidthVp(menu.items))
            .backgroundColor('#FFFFFF')
            .border({ width: 1, color: Theme.LINE })
            .shadow({ radius: 6, color: '#40000000', offsetX: 2, offsetY: 2 })
            .position(this.childPanelPosition(menu.items))
            .onHover((hover: boolean) => {
              this.childPanelHovered = hover;
              if (!hover) {
                this.scheduleCloseSubmenu();
              }
            })
          }
        }
        .width('100%')
        .onAreaChange((_old: Area, area: Area) => {
          if (area.globalPosition) {
            this.panelGlobalX = Number(area.globalPosition.x);
            this.panelGlobalY = Number(area.globalPosition.y);
          }
        })
      }
    })
  }
}
