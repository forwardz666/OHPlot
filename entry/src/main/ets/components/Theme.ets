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
