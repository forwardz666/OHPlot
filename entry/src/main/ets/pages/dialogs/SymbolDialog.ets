// SymbolDialog — "Choose Symbol" dialog (batch 2).
// Special-character selection: grid of character buttons across
// multiple categories (math, lower/upper Greek, arrows, numbers).
// Click inserts selected char; OK returns it.
import qohos from 'libqohos.so';
import hilog from '@ohos.hilog';
import { getAppString } from '../../components/LocaleHelper';
import * as Theme from '../../components/Theme';

const DOMAIN: number = 0x0000;
const TAG: string = 'OHPlot';

interface QohosInjector {
  callQtCommand(cmd: string, argsJson: string): string;
}

interface AddTextArgs {
  text: string;
}

interface CharCategoryDef {
  id: string;
  label: string;
  chars: string[];
}

// Character sets matching Qt SymbolDialog charsets
const CHAR_CATEGORIES: CharCategoryDef[] = [
  {
    id: 'math',
    label: 'dlg_sym_math',
    chars: [
      '∀', '∁', '∂', '∃', '∄', '∅', '∆', '∇', '∈', '∉',
      '∊', '∋', '∌', '∍', '∎', '∏', '∐', '∑', '∓', '∔',
      '∕', '∖', '∗', '∘', '∙', '√', '∛', '∜', '∝', '∞',
      '∟', '∠', '∣', '∤', '∥', '∧', '∨', '∩', '∪', '∫',
      '∬', '∭', '∰', '±', '∸', '≈', '≅', '≊', '≋', '≌',
      '≍', '≎', '≏', '≐', '≑', '≠', '≡', '≢', '≤', '≥',
      '≦', '≧', '≨', '≩', '≪', '≫', '⊂', '⊃', '⊄', '⊅',
      '⊆', '⊇', '⊈', '⊉', '⊊', '⊋', '⊬', '⊭', '⊮', '⊯',
      'ℏ', 'Å', '‰', '‱'
    ]
  },
  {
    id: 'lower_greek',
    label: 'dlg_sym_lower_greek',
    chars: [
      'α', 'β', 'γ', 'δ', 'ε', 'ζ', 'η', 'θ', 'ι', 'κ',
      'λ', 'μ', 'ν', 'ξ', 'ο', 'π', 'ρ', 'ς', 'σ', 'τ',
      'υ', 'φ', 'χ', 'ψ', 'ω', 'ϐ', 'ϕ', 'ϖ', 'ϰ', 'ϱ'
    ]
  },
  {
    id: 'upper_greek',
    label: 'dlg_sym_upper_greek',
    chars: [
      'Α', 'Β', 'Γ', 'Δ', 'Ε', 'Ζ', 'Η', 'Θ', 'Ι', 'Κ',
      'Λ', 'Μ', 'Ν', 'Ξ', 'Ο', 'Π', 'Ρ', 'Σ', 'Τ', 'Υ',
      'Φ', 'Χ', 'Ψ', 'Ω'
    ]
  },
  {
    id: 'arrows',
    label: 'dlg_sym_arrows',
    chars: [
      '←', '↑', '→', '↓', '↔', '↕', '↖', '↗', '↘', '↙',
      '↚', '↛', '↜', '↝', '↞', '↟', '↠', '↡', '↢', '↣',
      '↤', '↥', '↦', '↧', '⇐', '⇑', '⇒', '⇓', '⇔', '⇕',
      '⇆', '⇇', '⇈', '⇉', '⇊'
    ]
  },
  {
    id: 'numbers',
    label: 'dlg_sym_numbers',
    chars: [
      '⅓', '⅔', '⅕', '⅖', '⅗', '⅘', '⅙', '⅚', '⅛', '⅜',
      '⅝', '⅞', '⅐', '⅑', '⅒', 'ⅰ', 'ⅱ', 'ⅲ', 'ⅳ', 'ⅴ',
      'ⅵ', 'ⅶ', 'ⅷ', 'ⅸ', 'ⅹ', 'ⅺ', 'ⅻ', 'ⅼ', 'ⅽ', 'ⅾ',
      'ⅿ'
    ]
  }
];

@Component
export struct SymbolDialog {
  @Link @Watch('onVisibleChanged') isVisible: boolean;
  @State categoryIdx: number = 0;
  @State selectedChar: string = '';
  @State outputText: string = '';

  aboutToAppear(): void {
    if (this.isVisible) {
      this.resetDefaults();
    }
  }

  onVisibleChanged(): void {
    if (this.isVisible) {
      this.resetDefaults();
    }
  }

  private resetDefaults(): void {
    this.categoryIdx = 0;
    this.selectedChar = '';
    this.outputText = '';
  }

  private onCharPick(ch: string): void {
    this.selectedChar = ch;
    this.outputText = this.outputText + ch;
  }

  private onOk(): void {
    if (this.outputText.trim().length > 0) {
      try {
        const injector = qohos as QohosInjector;
        const args: AddTextArgs = { text: this.outputText };
        const result: string = injector.callQtCommand('addText', JSON.stringify(args));
        hilog.info(DOMAIN, TAG, 'addText queued from SymbolDialog: %{public}s', result);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'addText failed from SymbolDialog: %{public}s', (e as Error).message);
      }
    }
    this.isVisible = false;
  }

  build() {
    if (this.isVisible) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#80000000')
          .onClick(() => { this.isVisible = false; })

        Column() {
          Text(getAppString('dlg_choose_symbol'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .margin({ top: 16, bottom: 12 })

          // Category tabs
          Scroll() {
            Row() {
              ForEach(CHAR_CATEGORIES, (cat: CharCategoryDef, idx: number) => {
                Text(getAppString(cat.label))
                  .fontSize(12)
                  .fontColor(idx === this.categoryIdx ? '#0078D7' : '#666666')
                  .fontWeight(idx === this.categoryIdx ? FontWeight.Bold : FontWeight.Normal)
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .backgroundColor(idx === this.categoryIdx ? '#E0E8F0' : '#F0F0F0')
                  .borderRadius(4)
                  .margin({ right: 4 })
                  .onClick(() => { this.categoryIdx = idx; })
              }, (cat: CharCategoryDef, idx: number) => cat.id + ':' + idx)
            }
          }
          .width('100%')
          .scrollable(ScrollDirection.Horizontal)
          .padding({ left: 16, right: 16 })
          .margin({ bottom: 8 })

          // Character grid
          Scroll() {
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(CHAR_CATEGORIES[this.categoryIdx].chars, (ch: string, idx: number) => {
                Text(ch)
                  .fontSize(20)
                  .fontColor(ch === this.selectedChar ? '#0078D7' : Theme.TEXT)
                  .fontWeight(ch === this.selectedChar ? FontWeight.Bold : FontWeight.Normal)
                  .width(40)
                  .height(40)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(ch === this.selectedChar ? '#E0E8F0' : '#F8F8F8')
                  .border({ width: 1, color: '#D0D0D0' })
                  .borderRadius(4)
                  .margin(2)
                  .onClick(() => { this.onCharPick(ch); })
              }, (ch: string, idx: number) => ch + ':' + idx)
            }
            .padding({ left: 16, right: 16 })
          }
          .layoutWeight(1)
          .width('100%')

          // Output field
          Row() {
            Text(getAppString('dlg_inserted_text'))
              .fontSize(13)
              .fontColor('#555555')
              .width(80)
            TextInput({ text: this.outputText })
              .layoutWeight(1)
              .fontSize(14)
              .fontColor(Theme.TEXT)
              .onChange((value: string) => { this.outputText = value; })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8 })

          Row() {
            Button(getAppString('common_close'))
              .fontSize(14).height(32)
              .backgroundColor('#E0E0E0').fontColor('#333333').borderRadius(4)
              .onClick(() => { this.isVisible = false; })
            Button(getAppString('common_ok'))
              .fontSize(14).height(32)
              .backgroundColor('#0078D7').fontColor('#FFFFFF').borderRadius(4)
              .margin({ left: 12 })
              .onClick(() => { this.onOk(); })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16, top: 8 })
          .justifyContent(FlexAlign.End)
        }
        .width(420)
        .constraintSize({ maxHeight: '80%' })
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .shadow({ radius: 12, color: '#60000000', offsetX: 4, offsetY: 4 })
      }
      .width('100%')
      .height('100%')
    }
  }
}
