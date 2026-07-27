// ArkSciDAVis Menu Bar Component
// Implements precise menu interaction logic:
// - onClick: toggle current menu open/close
// - onHover: switch to current menu only if another menu is already open
import hilog from '@ohos.hilog';

const DOMAIN: number = 0x0000;
const TAG: string = 'ArkSciDAVis';

interface SubMenuItemData {
  id: string;
  label: string;
  shortcut?: string;
  // Menu-state flags driven by getUiState (undo/redo, window list...):
  // enabled=false renders grey and swallows the tap; checked=true shows ✓.
  enabled?: boolean;
  checked?: boolean;
}

interface MenuItemData {
  id: string;
  label: string;
  items?: SubMenuItemData[];
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

  build() {
    Column() {
      Row() {
        ForEach(this.menus, (menu: MenuItemData) => {
          Text(menu.label)
            .fontSize(14)
            .fontColor(this.openMenu === menu.id ? '#000000' : '#333333')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .onClick(() => {
              this.openMenu = this.openMenu === menu.id ? null : menu.id;
            })
            .onHover((isHover: boolean) => {
              if (isHover && this.openMenu !== null && this.openMenu !== menu.id) {
                this.openMenu = menu.id;
              }
            })
        })
      }
      .width('100%')
      .height(28)
      .backgroundColor('#F0F0F0')
      .padding({ left: 2 })
      .border({ width: { bottom: 1 }, color: '#CCCCCC' })

      // Dropdown menu (shown when a menu is open)
      DropdownMenu({ openMenu: this.openMenu, menus: this.menus })
    }
  }
}

@Component
export struct DropdownMenu {
  @Link openMenu: string | null;
  @Prop menus: MenuItemData[] = [];
  onItemClick?: (itemId: string) => void;

  build() {
    if (this.openMenu !== null) {
      Column() {
        SubMenuItems({ openMenu: this.openMenu, menus: this.menus })
      }
      .width(200)
      .backgroundColor('#FFFFFF')
      .border({ width: 1, color: '#CCCCCC' })
      .shadow({ radius: 6, color: '#40000000', offsetX: 2, offsetY: 2 })
    }
  }
}

@Component
struct SubMenuItems {
  @Link openMenu: string | null;
  @Prop menus: MenuItemData[] = [];
  onItemClick?: (itemId: string) => void;

  build() {
    ForEach(this.menus, (menu: MenuItemData) => {
      if (this.openMenu === menu.id) {
        ForEach(menu.items || [], (subItem: SubMenuItemData) => {
          if (subItem.id.startsWith('sep')) {
            // Separator line
            Row()
              .width('100%')
              .height(1)
              .backgroundColor('#E0E0E0')
              .margin({ top: 2, bottom: 2 })
          } else if (subItem.id === 'paste' && subItem.enabled !== false) {
            // Security component: clicking grants a one-shot temporary
            // READ_PASTEBOARD authorization (the full ACL permission is not
            // grantable with the debug signing profile).  Label/icon are
            // system-fixed, styled to blend into the menu.
            Row() {
              PasteButton({ icon: PasteIconStyle.LINES, text: PasteDescription.PASTE,
                buttonType: ButtonType.Normal })
                .fontSize(14)
                .fontColor('#000000')
                .iconSize(14)
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
              Blank()
              if (subItem.shortcut) {
                Text(subItem.shortcut)
                  .fontSize(12)
                  .fontColor('#888888')
                  .margin({ left: 20 })
              }
            }
            .width('100%')
            .height(28)
            .padding({ left: 24, right: 12 })
            .alignItems(VerticalAlign.Center)
          } else {
            Row() {
              Text(subItem.checked === true ? '✓ ' + subItem.label : subItem.label)
                .fontSize(14)
                .fontColor(subItem.enabled === false ? '#A8A8A8' : '#000000')
                .layoutWeight(1)
              if (subItem.shortcut) {
                Text(subItem.shortcut)
                  .fontSize(12)
                  .fontColor(subItem.enabled === false ? '#C8C8C8' : '#888888')
                  .margin({ left: 20 })
              }
            }
            .width('100%')
            .height(28)
            .padding({ left: 24, right: 12 })
            .alignItems(VerticalAlign.Center)
            .onHover((hover: boolean) => {
              if (hover) {
                hilog.info(DOMAIN, TAG, 'submenu hover: %{public}s', subItem.id);
              }
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
        })
      }
    })
  }
}
