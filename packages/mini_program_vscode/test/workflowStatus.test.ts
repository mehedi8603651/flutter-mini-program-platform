import assert from 'node:assert/strict';
import test from 'node:test';
import { parseWorkflowStatusJson } from '../src/workflowStatus';

test('parses workflow status JSON', () => {
  const report = parseWorkflowStatusJson(
    JSON.stringify({
      schemaVersion: 1,
      command: 'workflow status',
      workspace: { type: 'mini_program' },
      ready: true,
      severity: 'ok',
    }),
  );

  assert.equal(report.schemaVersion, 1);
  assert.equal(report.command, 'workflow status');
  assert.equal(report.ready, true);
});

test('parses JSON when command output has surrounding text', () => {
  const report = parseWorkflowStatusJson(`log before
{
  "schemaVersion": 1,
  "command": "workflow status",
  "ready": false
}
log after`);

  assert.equal(report.ready, false);
});

test('rejects non-workflow JSON', () => {
  assert.throws(
    () =>
      parseWorkflowStatusJson(
        JSON.stringify({ schemaVersion: 1, command: 'env status' }),
      ),
    /Unexpected workflow status/,
  );
});
