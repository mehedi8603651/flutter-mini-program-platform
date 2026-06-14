export type GuidedWorkflowId =
  | 'setupNewMiniProgram'
  | 'publishMiniProgramStatic'
  | 'preparePartnerHandoff'
  | 'setupHostApp'
  | 'addMiniProgramToHost'
  | 'runHostSmokeTest';

export interface GuidedWorkflow {
  readonly id: GuidedWorkflowId;
  readonly title: string;
  readonly description: string;
  readonly steps: readonly string[];
}

export const guidedWorkflows: readonly GuidedWorkflow[] = [
  {
    id: 'setupNewMiniProgram',
    title: 'Setup New MiniProgram',
    description: 'Create a mini-program, build it, validate it, and open the folder.',
    steps: ['create', 'build', 'validate'],
  },
  {
    id: 'publishMiniProgramStatic',
    title: 'Publish MiniProgram Static Artifacts',
    description: 'Build, validate, and publish public static mini-program artifacts.',
    steps: ['build', 'validate', 'publish-static'],
  },
  {
    id: 'preparePartnerHandoff',
    title: 'Prepare Partner Handoff',
    description: 'Build, validate, publish static artifacts, and write a partner package.',
    steps: [
      'build',
      'validate',
      'publish-static',
      'create-partner-package',
      'validate-partner-package',
    ],
  },
  {
    id: 'setupHostApp',
    title: 'Setup Host App',
    description: 'Run embed init, then diagnose the host.',
    steps: ['embed-init', 'diagnose-host'],
  },
  {
    id: 'addMiniProgramToHost',
    title: 'Add MiniProgram to Host',
    description: 'Import or add an endpoint, then diagnose the host app.',
    steps: ['import-or-add-endpoint', 'diagnose-host'],
  },
  {
    id: 'runHostSmokeTest',
    title: 'Run Host Smoke Test',
    description: 'Diagnose the host and start a host run terminal on the selected device.',
    steps: ['diagnose-host', 'host-run'],
  },
];

export function guidedWorkflowById(
  id: GuidedWorkflowId,
): GuidedWorkflow {
  const workflow = guidedWorkflows.find((item) => item.id === id);
  if (!workflow) {
    throw new Error(`Unknown guided workflow: ${id}`);
  }
  return workflow;
}

export function formatGuidedWorkflowPlan(workflow: GuidedWorkflow): string {
  return [
    workflow.title,
    workflow.description,
    ...workflow.steps.map((step, index) => `${index + 1}. ${step}`),
  ].join('\n');
}
