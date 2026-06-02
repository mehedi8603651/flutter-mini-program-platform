import * as vscode from 'vscode';

import {
  buildPublisherBackendFirebaseDataExportArgs,
  buildPublisherBackendFirebaseDataImportArgs,
  buildPublisherBackendFirebaseDataRedemptionsArgs,
  buildPublisherBackendFirebaseDataStatusArgs,
  buildPublisherBackendFirebaseDeployArgs,
  buildPublisherBackendFirebaseDestroyArgs,
  buildPublisherBackendFirebaseOutputsArgs,
  buildPublisherBackendFirebaseSeedArgs,
  buildPublisherBackendFirebaseSmokeArgs,
  buildPublisherBackendFirebaseStatusArgs,
} from '../cli';

import {
  chooseFirebaseDataExportPath,
  chooseFirebaseDataImportFile,
  ensurePublisherBackendFirebaseCli032,
  ensurePublisherBackendFirebaseDataManagementCli034,
  ensurePublisherBackendFirebaseFirestoreCli032,
  ensurePublisherBackendFirebaseWriteSmokeCli035,
  promptOptionalFirebaseSmokeAccessKey,
  promptPublisherBackendFirebaseEnvName,
  requireMiniProgramRoot,
  runCliCommand,
  validateRedemptionLimit,
} from '../extensionSupport';

export async function publisherBackendFirebaseDeploy(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseCli032(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const ok = await runCliCommand(
    'Publisher Backend Firebase Deploy',
    buildPublisherBackendFirebaseDeployArgs({
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

export async function publisherBackendFirebaseStatus(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseCli032(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
  if (!envName) {
    return;
  }
  await runCliCommand(
    'Publisher Backend Firebase Status',
    buildPublisherBackendFirebaseStatusArgs({
      envName,
      miniProgramRoot: workspacePath,
      json: true,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

export async function publisherBackendFirebaseOutputs(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseCli032(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
  if (!envName) {
    return;
  }
  await runCliCommand(
    'Publisher Backend Firebase Outputs',
    buildPublisherBackendFirebaseOutputsArgs({
      envName,
      miniProgramRoot: workspacePath,
      json: false,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

export async function publisherBackendFirebaseSmoke(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseCli032(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const accessKey = await promptOptionalFirebaseSmokeAccessKey();
  if (accessKey === undefined) {
    return;
  }
  await runCliCommand(
    'Publisher Backend Firebase Smoke',
    buildPublisherBackendFirebaseSmokeArgs({
      envName,
      miniProgramRoot: workspacePath,
      accessKey,
    }),
    workspacePath,
    output,
  );
}

export async function publisherBackendFirebaseSmokeWrite(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseWriteSmokeCli035(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const accessKey = await promptOptionalFirebaseSmokeAccessKey();
  if (accessKey === undefined) {
    return;
  }
  const couponId = await vscode.window.showInputBox({
    prompt: 'Coupon ID for Firebase write smoke',
    value: 'coupon-10',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'Coupon ID is required.',
  });
  if (!couponId) {
    return;
  }
  const userId = await vscode.window.showInputBox({
    prompt: 'User ID for Firebase write smoke',
    value: 'smoke-user',
    ignoreFocusOut: true,
    validateInput: (value) => value.trim() ? undefined : 'User ID is required.',
  });
  if (!userId) {
    return;
  }
  const confirmation = await vscode.window.showWarningMessage(
    'Firebase write smoke calls POST /coupon/redeem and may create a Firestore redemption document.',
    { modal: true },
    'Run Write Smoke',
  );
  if (confirmation !== 'Run Write Smoke') {
    return;
  }
  await runCliCommand(
    'Publisher Backend Firebase Write Smoke',
    buildPublisherBackendFirebaseSmokeArgs({
      envName,
      miniProgramRoot: workspacePath,
      includeWrite: true,
      writeCouponId: couponId.trim(),
      writeUserId: userId.trim(),
      accessKey,
    }),
    workspacePath,
    output,
  );
}

export async function publisherBackendFirebaseSeed(
  output: vscode.OutputChannel,
  refreshStatus: (remote: boolean) => Promise<void>,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseFirestoreCli032(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const ok = await runCliCommand(
    'Publisher Backend Firebase Firestore Seed',
    buildPublisherBackendFirebaseSeedArgs({
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

export async function publisherBackendFirebaseDataStatus(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseFirestoreCli032(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
  if (!envName) {
    return;
  }
  await runCliCommand(
    'Publisher Backend Firebase Firestore Data Status',
    buildPublisherBackendFirebaseDataStatusArgs({
      envName,
      miniProgramRoot: workspacePath,
      json: false,
    }),
    workspacePath,
    output,
    { allowNonZeroExit: true },
  );
}

export async function publisherBackendFirebaseDataExport(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseDataManagementCli034(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
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
      title: 'Choose Firebase Firestore export scope',
      ignoreFocusOut: true,
    },
  );
  if (!includeMode) {
    return;
  }
  const outputPath = await chooseFirebaseDataExportPath(workspacePath, envName);
  if (!outputPath) {
    return;
  }
  await runCliCommand(
    'Publisher Backend Firebase Firestore Data Export',
    buildPublisherBackendFirebaseDataExportArgs({
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

export async function publisherBackendFirebaseDataImportDryRun(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseDataManagementCli034(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const inputPath = await chooseFirebaseDataImportFile(workspacePath);
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
      title: 'Choose Firebase Firestore import dry-run scope',
      ignoreFocusOut: true,
    },
  );
  if (!includeMode) {
    return;
  }
  await runCliCommand(
    'Publisher Backend Firebase Firestore Import Dry Run',
    buildPublisherBackendFirebaseDataImportArgs({
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

export async function publisherBackendFirebaseDataRedemptions(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseDataManagementCli034(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
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
    validateInput: validateRedemptionLimit,
  });
  if (!limit) {
    return;
  }
  await runCliCommand(
    'Publisher Backend Firebase Firestore Redemptions',
    buildPublisherBackendFirebaseDataRedemptionsArgs({
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

export async function publisherBackendFirebaseDestroy(
  output: vscode.OutputChannel,
): Promise<void> {
  const workspacePath = await requireMiniProgramRoot();
  if (!workspacePath) {
    return;
  }
  if (!(await ensurePublisherBackendFirebaseDataManagementCli034(workspacePath, output))) {
    return;
  }
  const envName = await promptPublisherBackendFirebaseEnvName(workspacePath);
  if (!envName) {
    return;
  }
  const mode = await vscode.window.showQuickPick(
    [
      {
        label: 'Guarded delete function',
        description: 'Delete only if the Firestore data guard allows it.',
        confirmDataLoss: false,
      },
      {
        label: 'Delete function despite Firestore data',
        description: 'Pass --confirm-data-loss after extra confirmation.',
        confirmDataLoss: true,
      },
    ],
    {
      title: 'Destroy Firebase publisher backend function',
      ignoreFocusOut: true,
    },
  );
  if (!mode) {
    return;
  }
  if (mode.confirmDataLoss) {
    const typed = await vscode.window.showInputBox({
      prompt: 'Type delete function to confirm Firebase Function deletion with Firestore data guard override',
      ignoreFocusOut: true,
      validateInput: (value) =>
        value.trim() === 'delete function'
          ? undefined
          : 'Type delete function to confirm.',
    });
    if (typed?.trim() !== 'delete function') {
      return;
    }
  } else {
    const confirmation = await vscode.window.showWarningMessage(
      'This will request Firebase Function deletion. The CLI will block deletion if Firestore app records or redemptions exist. Firestore data is not deleted.',
      { modal: true },
      'Run Guarded Delete',
    );
    if (confirmation !== 'Run Guarded Delete') {
      return;
    }
  }
  await runCliCommand(
    'Publisher Backend Firebase Destroy',
    buildPublisherBackendFirebaseDestroyArgs({
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
