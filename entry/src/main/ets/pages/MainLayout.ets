// ArkSciDAVis Main Layout - overlays on top of XComponent (Qt render)
// Phase 1: XComponent remains visible as backup underneath
//
// CRITICAL EVENT FLOW:
// - MenuBar area: ArkTS handles menu clicks. No event passes to Qt.
// - Content area: HitTestMode.Transparent - touch events pass through to
//   the XComponent underneath, where QPA's native callbacks handle them.
//   Left-button events are also forwarded via NAPI sendMouse().
// - StatusBar area: ArkTS handles status display.
// - When a sub-menu is open, a transparent overlay catches external
//   clicks to close the menu, then passes the event through to Qt.
import { MenuBar } from '../components/MenuBar';
import { StatusBar } from '../components/StatusBar';
import { NoteEditor } from './NoteEditor';
import hilog from '@ohos.hilog';
import qohos from 'libqohos.so';

interface QohosInjector {
  sendMouse(x: number, y: number, button: number, action: number): boolean;
}

const qtInjector = qohos as QohosInjector;

const DOMAIN: number = 0x0000;
const TAG: string = 'QtInput';

let leftDown: boolean = false;

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
export struct MainLayout {
  @State openMenu: string | null = null;
  @State showNotes: boolean = false;
  @State statusText: string = '';

  private menuDefs: MenuItemData[] = [
    { id: 'file', label: 'File', items: [
      { id: 'new_project', label: 'New Project' },
      { id: 'new_table', label: 'New Table' },
      { id: 'new_notes', label: 'New Notes', shortcut: 'Ctrl+N' },
      { id: 'new_matrix', label: 'New Matrix' },
      { id: 'sep1', label: '─' },
      { id: 'open', label: 'Open...', shortcut: 'Ctrl+O' },
      { id: 'close', label: 'Close' },
      { id: 'sep2', label: '─' },
      { id: 'save', label: 'Save Project', shortcut: 'Ctrl+S' },
      { id: 'save_as', label: 'Save Project As...' },
      { id: 'sep3', label: '─' },
      { id: 'import', label: 'Import' },
      { id: 'export', label: 'Export' },
      { id: 'sep4', label: '─' },
      { id: 'print', label: 'Print...', shortcut: 'Ctrl+P' },
      { id: 'sep5', label: '─' },
      { id: 'quit', label: 'Quit', shortcut: 'Ctrl+Q' }
    ]},
    { id: 'edit', label: 'Edit', items: [
      { id: 'undo', label: 'Undo', shortcut: 'Ctrl+Z' },
      { id: 'redo', label: 'Redo', shortcut: 'Ctrl+Y' },
      { id: 'sep1', label: '─' },
      { id: 'cut', label: 'Cut', shortcut: 'Ctrl+X' },
      { id: 'copy', label: 'Copy', shortcut: 'Ctrl+C' },
      { id: 'paste', label: 'Paste', shortcut: 'Ctrl+V' },
      { id: 'delete', label: 'Delete' },
      { id: 'sep2', label: '─' },
      { id: 'select_all', label: 'Select All', shortcut: 'Ctrl+A' }
    ]},
    { id: 'view', label: 'View', items: [
      { id: 'toolbars', label: 'Toolbars' },
      { id: 'sep1', label: '─' },
      { id: 'plots', label: 'Plots' },
      { id: 'tables', label: 'Tables' },
      { id: 'notes', label: 'Notes' },
      { id: 'log', label: 'Log' },
      { id: 'script_console', label: 'Script Console' }
    ]},
    { id: 'table', label: 'Table', items: [
      { id: 'add_columns', label: 'Add Columns...' },
      { id: 'set_values', label: 'Set Column Values...' },
      { id: 'sort', label: 'Sort Table' },
      { id: 'sep1', label: '─' },
      { id: 'statistics', label: 'Table Statistics' }
    ]},
    { id: 'plot', label: 'Plot', items: [
      { id: 'add_remove', label: 'Add/Remove Curves...' },
      { id: 'add_error_bars', label: 'Add Error Bars...' },
      { id: 'sep1', label: '─' },
      { id: 'plot_2d', label: '2D Plot' },
      { id: 'plot_3d', label: '3D Plot' }
    ]},
    { id: 'analysis', label: 'Analysis', items: [
      { id: 'fit', label: 'Fit' },
      { id: 'fft', label: 'FFT' },
      { id: 'smooth', label: 'Smooth' },
      { id: 'sep1', label: '─' },
      { id: 'integrate', label: 'Integrate' },
      { id: 'differentiate', label: 'Differentiate' }
    ]},
    { id: 'help', label: 'Help', items: [
      { id: 'help', label: 'Help...' },
      { id: 'sep1', label: '─' },
      { id: 'about', label: 'About SciDAVis...' }
    ]}
  ];

  build() {
    Stack() {
      // Layer 1 (bottom): XComponent lives BELOW this Stack.
      // This is the Qt rendering surface - events must pass through to it.

      // Layer 2: Main layout with menu bar, content area, status bar
      Column() {
        // Menu bar
        MenuBar({
          openMenu: this.openMenu,
          menus: this.menuDefs
        })

        // Content area: transparent - events pass through to XComponent
        Column()
          .layoutWeight(1)
          .hitTestBehavior(HitTestMode.Transparent)
          .onTouch((event: TouchEvent) => {
            // Forward touch events (left-button clicks converted by ArkUI)
            // as mouse events to Qt via NAPI
            const changed: TouchObject[] = event.changedTouches;
            for (let i = 0; i < changed.length; i++) {
              const t: TouchObject = changed[i];
              let action: number = -1;
              if (t.type === TouchType.Down) {
                action = 0; leftDown = true;
              } else if (t.type === TouchType.Up) {
                action = 1; leftDown = false;
              } else if (t.type === TouchType.Move && leftDown) {
                action = 2;
              }
              if (action >= 0 && action !== 2) {
                qtInjector.sendMouse(t.x, t.y, 1, action);
              }
            }
          })
          .onMouse((event: MouseEvent) => {
            // Forward left-button drag
            if (event.button === MouseButton.Left && event.action === MouseAction.Move && leftDown) {
              qtInjector.sendMouse(event.x, event.y, 1, 2);
            }
          })

        // Status bar
        StatusBar({ statusText: this.statusText })
      }

      // Layer 3 (top): External-click overlay to close sub-menus.
      // Only shown when a sub-menu is open.
      // HitTestMode.Transparent: we catch the touch to close the menu,
      // then let the event pass through to the XComponent (Qt).
      if (this.openMenu !== null) {
        Column()
          .width('100%')
          .height('100%')
          .hitTestBehavior(HitTestMode.Transparent)
          .onTouch(() => {
            this.openMenu = null;
          })
      }
    }
    .width('100%')
    .height('100%')
  }
}
