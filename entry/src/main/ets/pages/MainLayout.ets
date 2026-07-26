// ArkSciDAVis Main Layout - overlays on top of XComponent (Qt render)
// Phase 1: XComponent remains visible as backup underneath
import { MenuBar } from '../components/MenuBar';
import { StatusBar } from '../components/StatusBar';
import { NoteEditor } from './NoteEditor';

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
  @State currentLocale: string = 'en';
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
    Column() {
      MenuBar({
        currentLocale: this.currentLocale,
        menus: this.menuDefs
      })

      if (this.showNotes) {
        NoteEditor({ currentLocale: this.currentLocale })
          .layoutWeight(1)
      } else {
        Column()
          .layoutWeight(1)
          .hitTestBehavior(HitTestMode.Transparent)
      }

      StatusBar({ currentLocale: this.currentLocale, statusText: this.statusText })
    }
    .width('100%')
    .height('100%')
  }
}
