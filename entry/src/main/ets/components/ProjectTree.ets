import hilog from '@ohos.hilog';
import qohos from 'libqohos.so';

interface QohosInjector {
  sendMouse(x: number, y: number, button: number, action: number): boolean;
  callQtCommand(cmd: string, argsJson: string): string;
}

const qtInjector = qohos as QohosInjector;

const DOMAIN: number = 0x0000;
const TAG: string = 'ProjectTree';

interface TreeNode {
  name: string;
  type: string;
  children: TreeNode[];
}

interface TreeResponse {
  success: boolean;
  data?: TreeNode;
  error?: string;
}

interface FlatRow {
  name: string;
  type: string;
  depth: number;
  isFolder: boolean;
  expanded: boolean;
}

@Component
export struct ProjectTree {
  @Prop @Watch('onTickChange') refreshTick: number = 0;
  @Prop activeName: string = '';
  onActivate: (name: string) => void = (_name: string) => {};
  @State private rows: FlatRow[] = [];
  @State private collapsedKeys: string[] = [];

  private onTickChange(): void {
    this.reload();
  }

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    try {
      const raw: string = qtInjector.callQtCommand('getProjectTree', '{}');
      const resp: TreeResponse = JSON.parse(raw) as TreeResponse;
      if (resp.success && resp.data !== undefined) {
        this.flattenTree(resp.data, 0);
      } else {
        const errMsg: string = resp.error !== undefined ? resp.error : 'unknown';
        hilog.warn(DOMAIN, TAG, 'getProjectTree failed: %{public}s', errMsg);
        this.rows = [];
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getProjectTree exception: %{public}s', (e as Error).message);
      this.rows = [];
    }
  }

  private isCollapsed(depth: number, name: string): boolean {
    const key: string = depth + '/' + name;
    for (let i = 0; i < this.collapsedKeys.length; i++) {
      if (this.collapsedKeys[i] === key) {
        return true;
      }
    }
    return false;
  }

  private setCollapsed(depth: number, name: string, collapsed: boolean): void {
    const key: string = depth + '/' + name;
    if (collapsed) {
      for (let i = 0; i < this.collapsedKeys.length; i++) {
        if (this.collapsedKeys[i] === key) {
          return;
        }
      }
      this.collapsedKeys = [...this.collapsedKeys, key];
    } else {
      const next: string[] = [];
      for (let i = 0; i < this.collapsedKeys.length; i++) {
        if (this.collapsedKeys[i] !== key) {
          next.push(this.collapsedKeys[i]);
        }
      }
      this.collapsedKeys = next;
    }
  }

  private flattenTree(root: TreeNode, depth: number): void {
    const newRows: FlatRow[] = [];
    this.doFlatten(root, depth, newRows);
    this.rows = newRows;
  }

  private doFlatten(node: TreeNode, depth: number, out: FlatRow[]): void {
    const isFolder: boolean = node.type === 'Folder';
    const collapsed: boolean = isFolder && this.isCollapsed(depth, node.name);
    out.push({
      name: node.name,
      type: node.type,
      depth: depth,
      isFolder: isFolder,
      expanded: !collapsed
    });
    if (isFolder && !collapsed && node.children.length > 0) {
      for (let i = 0; i < node.children.length; i++) {
        this.doFlatten(node.children[i], depth + 1, out);
      }
    }
  }

  private typeIcon(t: string): string {
    if (t === 'Table') return '\u25A3';
    if (t === 'Matrix') return '\u25A6';
    if (t === 'MultiLayer') return '\u25C6';
    if (t === 'Note') return '\u25A8';
    return '\u2500';
  }

  private toggleFolder(row: FlatRow): void {
    this.setCollapsed(row.depth, row.name, row.expanded);
    this.reload();
  }

  build() {
    Column() {
      Row() {
        Text($r('app.string.panel_project'))
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .layoutWeight(1)
          .padding({ left: 8 })
        Text('\u21BB')
          .fontSize(14)
          .fontColor('#666666')
          .padding({ right: 8 })
          .onClick(() => {
            this.reload();
          })
      }
      .width('100%')
      .height(28)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#E8E8E8')
      .border({ width: { bottom: 1 }, color: '#CCCCCC' })

      Scroll() {
        Column() {
          ForEach(this.rows, (row: FlatRow) => {
            Row() {
              if (row.isFolder) {
                Text(row.expanded ? '\u25BC' : '\u25B6')
                  .fontSize(10)
                  .fontColor('#666666')
                  .margin({ right: 4 })
              } else {
                Text(this.typeIcon(row.type))
                  .fontSize(10)
                  .fontColor('#666666')
                  .margin({ right: 4 })
              }
              Text(row.name)
                .fontSize(12)
                .fontColor(row.name === this.activeName ? Color.White : '#333333')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
            .height(28)
            .padding({ left: row.depth * 14 + 8 })
            .alignItems(VerticalAlign.Center)
            .backgroundColor(row.name === this.activeName ? '#3A6EA5' : Color.Transparent)
            .onClick(() => {
              if (row.isFolder) {
                this.toggleFolder(row);
              }
            })
            .gesture(
              TapGesture({ count: 2 })
                .onAction(() => {
                  if (!row.isFolder) {
                    this.onActivate(row.name);
                  }
                })
            )
          }, (row: FlatRow) => row.depth + '/' + row.name)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
  }
}
