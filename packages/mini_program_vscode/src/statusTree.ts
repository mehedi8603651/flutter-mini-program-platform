import * as vscode from 'vscode';

import {
  FirebaseHostEndpointStatus,
  StatusTreeSection,
  StatusTreeRow,
  buildStatusTreeSections,
} from './statusTreeModel';
import { WorkflowStatusReport } from './workflowStatus';

type StatusTreeNode = SectionNode | RowNode;

interface SectionNode {
  readonly kind: 'section';
  readonly label: string;
  readonly icon: string;
  readonly rows: StatusTreeRow[];
}

interface RowNode {
  readonly kind: 'row';
  readonly label: string;
  readonly value?: string;
  readonly icon?: string;
}

export class MiniProgramStatusTreeProvider implements vscode.TreeDataProvider<StatusTreeNode> {
  private readonly changeEmitter = new vscode.EventEmitter<StatusTreeNode | undefined>();
  private sections: StatusTreeSection[] = buildStatusTreeSections(undefined);
  private errorMessage: string | undefined;
  private report: WorkflowStatusReport | undefined;
  private firebaseHostEndpoint: FirebaseHostEndpointStatus | undefined;

  readonly onDidChangeTreeData = this.changeEmitter.event;

  setReport(report: WorkflowStatusReport): void {
    this.errorMessage = undefined;
    this.report = report;
    this.sections = buildStatusTreeSections(report, {
      firebaseHostEndpoint: this.firebaseHostEndpoint,
    });
    this.changeEmitter.fire(undefined);
  }

  setFirebaseHostEndpointStatus(status: FirebaseHostEndpointStatus): void {
    this.errorMessage = undefined;
    this.firebaseHostEndpoint = status;
    this.sections = buildStatusTreeSections(this.report, {
      firebaseHostEndpoint: this.firebaseHostEndpoint,
    });
    this.changeEmitter.fire(undefined);
  }

  setError(message: string): void {
    this.errorMessage = message;
    this.report = undefined;
    this.sections = [
      {
        label: 'Workspace',
        icon: 'error',
        rows: [{ label: 'Status failed', value: message }],
      },
    ];
    this.changeEmitter.fire(undefined);
  }

  getTreeItem(element: StatusTreeNode): vscode.TreeItem {
    if (element.kind === 'section') {
      const item = new vscode.TreeItem(
        element.label,
        element.rows.length > 0
          ? vscode.TreeItemCollapsibleState.Expanded
          : vscode.TreeItemCollapsibleState.None,
      );
      item.iconPath = new vscode.ThemeIcon(element.icon);
      item.tooltip = element.label;
      return item;
    }

    const item = new vscode.TreeItem(element.label, vscode.TreeItemCollapsibleState.None);
    item.description = element.value;
    item.tooltip = element.value ? `${element.label}: ${element.value}` : element.label;
    item.iconPath = new vscode.ThemeIcon(element.icon ?? 'circle-small-filled');
    return item;
  }

  getChildren(element?: StatusTreeNode): Thenable<StatusTreeNode[]> {
    if (!element) {
      return Promise.resolve(
        this.sections.map((section) => ({
          kind: 'section',
          label: section.label,
          icon: section.icon,
          rows: section.rows,
        })),
      );
    }
    if (element.kind === 'section') {
      return Promise.resolve(
        element.rows.map((row) => ({
          kind: 'row',
          label: row.label,
          value: row.value,
          icon: row.icon,
        })),
      );
    }
    return Promise.resolve([]);
  }

  getParent(): vscode.ProviderResult<StatusTreeNode> {
    return undefined;
  }

  get hasError(): boolean {
    return this.errorMessage !== undefined;
  }
}
