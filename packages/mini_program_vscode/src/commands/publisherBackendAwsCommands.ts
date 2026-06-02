import * as vscode from 'vscode';

import {
  buildPublisherBackendAwsDataExportArgs,
  buildPublisherBackendAwsDataImportArgs,
  buildPublisherBackendAwsDataRedemptionsArgs,
  buildPublisherBackendAwsDataStatusArgs,
  buildPublisherBackendAwsDeployArgs,
  buildPublisherBackendAwsDestroyArgs,
  buildPublisherBackendAwsLogsArgs,
  buildPublisherBackendAwsOutputsArgs,
  buildPublisherBackendAwsSeedArgs,
  buildPublisherBackendAwsSmokeArgs,
  buildPublisherBackendAwsStatusArgs,
} from '../cli';

import {
  chooseAwsDataExportPath,
  chooseAwsDataImportFile,
  ensurePublisherBackendAwsCli027,
  ensurePublisherBackendAwsCli028,
  promptPublisherBackendAwsEnvName,
  requireMiniProgramRoot,
  runCliCommand,
} from '../extensionSupport';

export async function publisherBackendAwsDeploy(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const ok = await runCliCommand(
    'Publisher Backend AWS Deploy',
    buildPublisherBackendAwsDeployArgs({
      envName,
      miniProgramRoot: workspacePath,
    }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(true);
  }
}

export async function publisherBackendAwsStatus(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS Status',
    buildPublisherBackendAwsStatusArgs({
      envName,
      miniProgramRoot: workspacePath,
      json: true,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

export async function publisherBackendAwsOutputs(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS Outputs',
    buildPublisherBackendAwsOutputsArgs({
      envName,
      miniProgramRoot: workspacePath,
      json: false,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

export async function publisherBackendAwsSmoke(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendAwsCli027(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS Smoke',
    buildPublisherBackendAwsSmokeArgs({
      envName,
      miniProgramRoot: workspacePath,
    }),
    workspacePath,
    output,
  );
}

export async function publisherBackendAwsSmokeWrite(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendAwsCli027(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const couponId = await vscode.window.showInputBox({
    prompt: 'Coupon ID for write smoke',
    value: 'coupon-10',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Coupon ID is required.',
  });
  if (!couponId) {
    return;
  }
  const userId = await vscode.window.showInputBox({
    prompt: 'User ID for write smoke',
    value: 'smoke-user',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'User ID is required.',
  });
  if (!userId) {
    return;
  }
  const confirmation = await vscode.window.showWarningMessage(
    'Write smoke calls POST /coupon/redeem and may create a DynamoDB redemption record.',
    { modal: true },
    'Run Write Smoke',
  );
  if (confirmation !== 'Run Write Smoke') {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS Write Smoke',
    buildPublisherBackendAwsSmokeArgs({
      envName,
      miniProgramRoot: workspacePath,
      includeWrite: true,
      writeCouponId: couponId.trim(),
      writeUserId: userId.trim(),
    }),
    workspacePath,
    output,
  );
}

export async function publisherBackendAwsSeed(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendAwsCli027(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const ok = await runCliCommand(
    'Publisher Backend AWS DynamoDB Seed',
    buildPublisherBackendAwsSeedArgs({
      envName,
      miniProgramRoot: workspacePath,
    }),
    workspacePath,
    output,
  );
  if (ok) {
    await refreshStatus(true);
  }
}

export async function publisherBackendAwsDataStatus(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendAwsCli027(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS DynamoDB Data Status',
    buildPublisherBackendAwsDataStatusArgs({
      envName,
      miniProgramRoot: workspacePath,
      json: false,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

export async function publisherBackendAwsDataExport(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendAwsCli028(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const includeMode = await vscode.window.showQuickPick(
    [
      {
        label: 'App records only',
        description: 'Export home, session, and coupons.',
        includeRedemptions: false,
      },
      {
        label: 'Include redemptions',
        description: 'Also export redemption history.',
        includeRedemptions: true,
      },
    ],
    {
      title: 'Choose AWS DynamoDB export scope',
      ignoreFocusOut: true,
    },
  );
  if (!includeMode) {
    return;
  }
  const outputPath = await chooseAwsDataExportPath(workspacePath, envName);
  if (!outputPath) {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS DynamoDB Data Export',
    buildPublisherBackendAwsDataExportArgs({
      envName,
      miniProgramRoot: workspacePath,
      output: outputPath,
      includeRedemptions: includeMode.includeRedemptions,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

export async function publisherBackendAwsDataImportDryRun(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendAwsCli028(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const inputPath = await chooseAwsDataImportFile(workspacePath);
  if (!inputPath) {
    return;
  }
  const includeMode = await vscode.window.showQuickPick(
    [
      {
        label: 'Skip redemptions',
        description: 'Validate only app records from the export.',
        includeRedemptions: false,
      },
      {
        label: 'Include redemptions',
        description: 'Validate redemption records too.',
        includeRedemptions: true,
      },
    ],
    {
      title: 'Choose AWS DynamoDB import dry-run scope',
      ignoreFocusOut: true,
    },
  );
  if (!includeMode) {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS DynamoDB Import Dry Run',
    buildPublisherBackendAwsDataImportArgs({
      envName,
      miniProgramRoot: workspacePath,
      input: inputPath,
      dryRun: true,
      includeRedemptions: includeMode.includeRedemptions,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

export async function publisherBackendAwsDataRedemptions(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendAwsCli028(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const couponId = await vscode.window.showInputBox({
    prompt: 'Optional coupon ID filter',
    placeHolder: 'coupon-20',
    ignoreFocusOut: true,
  });
  if (couponId === undefined) {
    return;
  }
  const userId = await vscode.window.showInputBox({
    prompt: 'Optional user ID filter',
    placeHolder: 'smoke-user',
    ignoreFocusOut: true,
  });
  if (userId === undefined) {
    return;
  }
  const limit = await vscode.window.showInputBox({
    prompt: 'Maximum redemption records to print',
    value: '50',
    ignoreFocusOut: true,
    validateInput: (value) => {
      const parsed = Number.parseInt(value.trim(), 10);
      return Number.isInteger(parsed) && parsed >= 1 && parsed <= 500
        ? undefined
        : 'Limit must be between 1 and 500.';
    },
  });
  if (!limit) {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS DynamoDB Redemptions',
    buildPublisherBackendAwsDataRedemptionsArgs({
      envName,
      miniProgramRoot: workspacePath,
      couponId: couponId.trim(),
      userId: userId.trim(),
      limit: limit.trim(),
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

export async function publisherBackendAwsLogs(output: vscode.OutputChannel): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const since = await vscode.window.showInputBox({
    prompt: 'CloudWatch log time range',
    value: '1h',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Time range is required.',
  });
  if (!since) {
    return;
  }
  await runCliCommand(
    'Publisher Backend AWS Logs',
    buildPublisherBackendAwsLogsArgs({
      envName,
      miniProgramRoot: workspacePath,
      since: since.trim(),
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

export async function publisherBackendAwsDestroy(output: vscode.OutputChannel): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendAwsCli028(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendAwsEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const mode = await vscode.window.showQuickPick(
    [
      {
        label: 'Guarded delete',
        description: 'Delete only if DynamoDB data guard allows it.',
        confirmDataLoss: false,
      },
      {
        label: 'Delete stack and DynamoDB data',
        description: 'Pass --confirm-data-loss after extra confirmation.',
        confirmDataLoss: true,
      },
    ],
    {
      title: 'Destroy AWS publisher backend stack',
      ignoreFocusOut: true,
    },
  );
  if (!mode) {
    return;
  }
  if (mode.confirmDataLoss) {
    const typed = await vscode.window.showInputBox({
      prompt: 'Type delete data to confirm stack and DynamoDB data deletion',
      ignoreFocusOut: true,
      validateInput: (value) =>
        value.trim() === 'delete data' ? undefined : 'Type delete data to confirm.',
    });
    if (typed?.trim() !== 'delete data') {
      return;
    }
  } else {
    const confirmation = await vscode.window.showWarningMessage(
      'This will request AWS stack deletion. The CLI will block deletion if stack-owned DynamoDB data exists.',
      { modal: true },
      'Run Guarded Delete',
    );
    if (confirmation !== 'Run Guarded Delete') {
      return;
    }
  }
  await runCliCommand(
    'Publisher Backend AWS Destroy',
    buildPublisherBackendAwsDestroyArgs({
      envName,
      miniProgramRoot: workspacePath,
      yes: true,
      confirmDataLoss: mode.confirmDataLoss,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}
