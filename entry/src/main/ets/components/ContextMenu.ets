// OHPlot Right-click Context Menu
// Shows a floating popup menu at the right-click position.
// Menu items are dynamic based on the active window type.

import display from '@ohos.display';

interface ContextMenuItem {
  id: string;
  label: string;
  isSeparator?: boolean;
}

interface Position {
  x: number;
  y: number;
}

@Component
export struct ContextMenu {
  @Link isVisible: boolean;
  // Parent (MainLayout) owns the click coordinates.  @Prop gives a one-way
  // data flow: when contextMenuX/Y change on the parent, these re-sync so
  // the menu pops up at the ACTUAL right-click position (was @State, which
  // only initialized once and left the menu stuck at (0,0)).
  @Prop positionX: number = 0;
  @Prop positionY: number = 0;
  @Prop activeType: string = '';
  onItemClick?: (itemId: string) => void;

  private getAdjustedPosition(): Position {
    let d = display.getDefaultDisplaySync();
    let screenWidth = d.width / d.densityPixels;
    let screenHeight = d.height / d.densityPixels;

    // Calculate menu height: items 28px, separators 5px, padding 10px
    let menuHeight = 10;
    let items = this.getMenuItems();
    for (let i = 0; i < items.length; i++) {
      if (items[i].isSeparator) {
        menuHeight += 5;
      } else {
        menuHeight += 28;
      }
    }

    let x = this.positionX;
    let y = this.positionY;

    if (x + 200 > screenWidth) {
      x = screenWidth - 210;
    }

    if (y + menuHeight > screenHeight) {
      y = screenHeight - menuHeight - 10;
    }

    return { x: x, y: y };
  }

  private getMenuItems(): ContextMenuItem[] {
    if (this.activeType === 'Table') {
      return [
        { id: 'cut', label: 'Cut' },
        { id: 'copy', label: 'Copy' },
        { id: 'paste', label: 'Paste' },
        { id: 'delete', label: 'Delete' },
        { id: 'sep1', label: '', isSeparator: true },
        { id: 'insert_row', label: 'Insert Row' },
        { id: 'insert_col', label: 'Insert Column' },
        { id: 'sep2', label: '', isSeparator: true },
        { id: 'clear_selection', label: 'Clear Selection' }
      ];
    } else if (this.activeType === 'MultiLayer') {
      return [
        { id: 'graph_props', label: 'Plot Properties' },
        { id: 'add_curve', label: 'Add/Remove Curve' },
        { id: 'add_error_bars', label: 'Add Error Bars' },
        { id: 'add_function', label: 'Add Function' },
        { id: 'sep1', label: '', isSeparator: true },
        { id: 'export_image', label: 'Export Image' }
      ];
    } else if (this.activeType === 'Matrix') {
      return [
        { id: 'set_dimensions', label: 'Set Dimensions' },
        { id: 'set_values', label: 'Set Values' },
        { id: 'sep1', label: '', isSeparator: true },
        { id: 'transpose', label: 'Transpose' },
        { id: 'invert', label: 'Invert' }
      ];
    } else {
      return [
        { id: 'cut', label: 'Cut' },
        { id: 'copy', label: 'Copy' },
        { id: 'paste', label: 'Paste' },
        { id: 'delete', label: 'Delete' }
      ];
    }
  }

  build() {
    if (this.isVisible) {
      Stack() {
        // Scrim: full-screen transparent overlay — taps outside the menu
        // dismiss it without acting on the content underneath.
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.isVisible = false;
          })

        // Context menu floating panel — styled identically to DropdownMenu
        // in MenuBar.ets: white background, hairline border, shadow.
        Column() {
          ForEach(this.getMenuItems(), (item: ContextMenuItem) => {
            if (item.isSeparator) {
              Row()
                .width('100%')
                .height(1)
                .backgroundColor('#E0E0E0')
                .margin({ top: 2, bottom: 2 })
            } else {
              Row() {
                Text(item.label)
                  .fontSize(14)
                  .fontColor('#000000')
              }
              .width('100%')
              .height(28)
              .padding({ left: 24, right: 12 })
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                if (this.onItemClick) {
                  this.onItemClick(item.id);
                }
                this.isVisible = false;
              })
            }
          }, (item: ContextMenuItem) => item.id)
        }
        .width(200)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#CCCCCC' })
        .shadow({ radius: 6, color: '#40000000', offsetX: 2, offsetY: 2 })
        .position({ x: this.getAdjustedPosition().x, y: this.getAdjustedPosition().y })
      }
      .width('100%')
      .height('100%')
    }
  }
}
