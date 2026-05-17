import assert from 'node:assert/strict';
import test from 'node:test';

import {
  formatGuidedWorkflowPlan,
  guidedWorkflowById,
  guidedWorkflows,
} from '../src/guidedWorkflows';

test('defines one-click guided workflows in expected order', () => {
  assert.deepEqual(
    guidedWorkflows.map((workflow) => workflow.id),
    [
      'setupNewMiniProgram',
      'publishMiniProgramToAws',
      'preparePartnerHandoff',
      'setupHostApp',
      'addMiniProgramToHost',
      'runHostSmokeTest',
    ],
  );
});

test('partner handoff workflow includes the complete publisher sequence', () => {
  assert.deepEqual(guidedWorkflowById('preparePartnerHandoff').steps, [
    'build',
    'validate',
    'publish-cloud',
    'create-access-key',
    'create-partner-package',
    'validate-partner-package',
  ]);
});

test('guided workflow plan is human-readable', () => {
  const plan = formatGuidedWorkflowPlan(guidedWorkflowById('addMiniProgramToHost'));
  assert.match(plan, /Add MiniProgram to Host/);
  assert.match(plan, /1\. import-or-add-endpoint/);
  assert.match(plan, /2\. diagnose-host/);
});
