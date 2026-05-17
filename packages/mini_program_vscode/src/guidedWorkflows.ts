export type GuidedWorkflowId =
  | 'setupNewMiniProgram'
  | 'publishMiniProgramToAws'
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
    id: 'publishMiniProgramToAws',
    title: 'Publish MiniProgram to AWS',
    description: 'Build, validate, publish to cloud, then run cloud diagnostics.',
    steps: ['build', 'validate', 'publish-cloud', 'diagnose-cloud'],
  },
  {
    id: 'preparePartnerHandoff',
    title: 'Prepare Partner Handoff',
    description: 'Build, validate, publish, create an access key, and write a partner package.',
    steps: [
      'build',
      'validate',
      'publish-cloud',
      'create-access-key',
      'create-partner-package',
      'validate-partner-package',
    ],
  },
  {
    id: 'setupHostApp',
    title: 'Setup Host App',
    description: 'Run embed init, optionally configure host cloud, then diagnose the host.',
    steps: ['embed-init', 'configure-host-cloud', 'diagnose-host'],
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
