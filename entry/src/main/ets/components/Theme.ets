// OHPlot shared chrome theme — single source of truth for the colours,
// borders and sizes used by the ArkTS chrome bands (menu bar, top toolbar,
// bottom toolbar, status bar, dropdown menus).  Collapsing the previously
// scattered literals here gives the four chrome bands a uniform look that
// matches the Windows SciDAVis light palette (problem 3: UI unity).

// Chrome background shared by menu bar / toolbars / status bar.
export const CHROME_BG: string = '#F0F0F0';
// Toolbar group (one Windows QToolBar segment) fill + border.
export const GROUP_BG: string = '#F7F7F7';
export const GROUP_BORDER: string = '#D6D6D6';
// Hairlines: chrome band separators, in-group separators, dropdown borders.
export const LINE: string = '#CCCCCC';
// Status bar now shares the chrome fill (was #E8E8E8) so all bands align.
export const STATUS_BG: string = '#F0F0F0';
// QToolBar-style grip strokes.
export const GRIP: string = '#C0C0C0';
// Text colours.
export const TEXT: string = '#333333';
export const TEXT_ACTIVE: string = '#000000';
export const TEXT_DISABLED: string = '#A8A8A8';
export const TEXT_STATUS: string = '#666666';
// Font sizes.
export const FS_MENU: number = 14;
export const FS_STATUS: number = 12;
// Band heights (vp).
export const H_MENU: number = 28;
export const H_STATUS: number = 24;
// Disabled button opacity (greyed toolbar buttons).
export const OPACITY_DISABLED: number = 0.4;

// ─── Dialog tokens (Win SciDAVis 2.7.2 light palette) ───────────────
// Derived from Windows QToolBar/QDialog chrome + reference screenshots
// (diagnostics/ui-alignment/2_对话框/).

// Dialog surface fill — the outer panel behind all content.
// Win dialogs use #F8F8F8 for the "page" area behind stacked groups;
// the Preferences left-nav uses a slightly darker #F5F5F5.
export const DIALOG_BG: string = '#F8F8F8';
// Dialog left-nav sidebar fill (darker than the content page).
export const DIALOG_SIDEBAR_BG: string = '#F5F5F5';
// Dialog border / separator between sections.
export const DIALOG_BORDER: string = '#E0E0E0';
// Accent blue — selected items, focused buttons, checkbox marks.
// Matches Win32 themed button highlight (#0078D7).
export const ACCENT: string = '#0078D7';
// Tooltip background (Win classic info-tip yellow).
export const TOOLTIP_BG: string = '#FFFFE1';
// List/scroll panel inner border (the 1px box around table lists).
export const PANEL_BORDER: string = '#D0D0D0';
// Selected-item highlight fill (light blue tint behind accent text).
export const SELECTED_BG: string = '#E8F4FD';
// Text colours — dialog-specific extensions.
export const TEXT_MUTED: string = '#555555';
export const TEXT_HINT: string = '#888888';
export const TEXT_LIST: string = '#666666';
export const TEXT_ERROR: string = '#CC3333';
export const TEXT_EMPTY: string = '#999999';

// ─── Spacing scale (vp) ─────────────────────────────────────────────
export const SPACING_4: number = 4;
export const SPACING_6: number = 6;
export const SPACING_8: number = 8;
export const SPACING_12: number = 12;
export const SPACING_16: number = 16;

// ─── Border radius scale (vp) ───────────────────────────────────────
export const RADIUS_4: number = 4;
export const RADIUS_8: number = 8;

// ─── Elevation / shadow ─────────────────────────────────────────────
// Standard dialog drop-shadow (matches .shadow({ radius, color, offsetX, offsetY })).
export const SHADOW_RADIUS: number = 12;
export const SHADOW_COLOR: string = '#60000000';
export const SHADOW_OFFSET_X: number = 4;
export const SHADOW_OFFSET_Y: number = 4;

// ─── Dialog font sizes (vp) ─────────────────────────────────────────
export const FS_DIALOG_TITLE: number = 18;
export const FS_DIALOG_LABEL: number = 14;
export const FS_DIALOG_BODY: number = 13;
export const FS_DIALOG_SMALL: number = 12;
export const FS_DIALOG_HINT: number = 11;

// ─── Button style tokens ────────────────────────────────────────────
export const BTN_HEIGHT: number = 32;
// Secondary / cancel button surface.
export const BTN_BG: string = '#E0E0E0';
export const BTN_BG_ACCENT: string = '#0078D7';
export const BTN_TEXT: string = '#333333';
export const BTN_TEXT_ACCENT: string = '#FFFFFF';
// Gap between adjacent buttons in a row.
export const BTN_GAP: number = 12;

// ─── Input field tokens ─────────────────────────────────────────────
export const INPUT_HEIGHT: number = 28;
export const INPUT_HEIGHT_TALL: number = 30;

// ─── Tab / sidebar nav style ────────────────────────────────────────
export const TAB_INACTIVE_BG: string = '#E9E9E9';
export const TAB_BORDER: string = '#C0C0C0';
export const SIDEBAR_SELECTED_BG: string = '#E8F4FD';
export const SIDEBAR_SELECTED_BORDER: string = '#99BFE8';
export const SIDEBAR_ITEM_HEIGHT: number = 36;

// ─── Backdrop ────────────────────────────────────────────────────────
export const BACKDROP_COLOR: string = '#80000000';
