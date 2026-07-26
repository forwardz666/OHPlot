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
}

interface MenuItemData {
  id: string;
  label: string;
  items?: SubMenuItemData[];
}

@Component
export struct MenuBar {
  @State openMenu: string | null = null;
  @Link currentLocale: string;
  menus: MenuItemData[] = [];

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
    .focusable(false)
  }
}

@Component
struct DropdownMenu {
  openMenu: string | null = null;
  menus: MenuItemData[] = [];

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
  openMenu: string | null = null;
  menus: MenuItemData[] = [];

  build() {
    ForEach(this.menus, (menu: MenuItemData) => {
      if (this.openMenu === menu.id) {
        ForEach(menu.items || [], (subItem: SubMenuItemData) => {
          Row() {
            Text(subItem.label)
              .fontSize(14)
              .fontColor('#000000')
              .layoutWeight(1)
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
          .onHover((hover: boolean) => {
            if (hover) {
              hilog.info(DOMAIN, TAG, 'submenu hover: %{public}s', subItem.id);
            }
          })
        })
      }
    })
  }
}
