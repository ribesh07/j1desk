// Display metadata + workflow rules, mirrored from the web app
// (src/lib/constants.ts and src/lib/workflow.ts). The server is always the authority;
// these are used for labels, colors and drag & drop hints only.

/// Color "tones" used by badges; actual colors live in theme.dart (light + dark).
enum Tone { gray, blue, green, yellow, orange, red, purple, pink }

class Meta {
  final String label;
  final Tone tone;
  const Meta(this.label, this.tone);
}

const statusMeta = <String, Meta>{
  'BACKLOG': Meta('Backlog', Tone.gray),
  'NEW': Meta('New', Tone.blue),
  'ASSIGNED': Meta('Assigned', Tone.purple),
  'ACCEPTED': Meta('Accepted', Tone.pink),
  'REJECTED': Meta('Rejected', Tone.red),
  'IN_PROGRESS': Meta('In Progress', Tone.yellow),
  'ON_HOLD': Meta('On Hold', Tone.orange),
  'PENDING': Meta('Pending', Tone.orange),
  'IN_REVIEW': Meta('In Review', Tone.blue),
  'RESOLVED': Meta('Resolved', Tone.green),
  'CLOSED': Meta('Closed', Tone.purple),
  'REOPENED': Meta('Reopened', Tone.red),
};

const statusDescriptions = <String, String>{
  'BACKLOG': 'Not planned yet',
  'NEW': 'Created but not yet assigned',
  'ASSIGNED': 'Waiting for the assignee to accept',
  'ACCEPTED': 'Accepted by the assignee',
  'REJECTED': 'Assignment rejected — needs reassignment',
  'IN_PROGRESS': 'Work has started',
  'ON_HOLD': 'Temporarily stopped',
  'PENDING': 'Waiting for information or feedback',
  'IN_REVIEW': 'Submitted for review',
  'RESOLVED': 'Work approved by reviewer',
  'CLOSED': 'Verified and closed',
  'REOPENED': 'Reopened — more work needed',
};

/// Kanban column order
const boardColumns = [
  'BACKLOG', 'NEW', 'ASSIGNED', 'ACCEPTED', 'IN_PROGRESS', 'ON_HOLD',
  'PENDING', 'IN_REVIEW', 'RESOLVED', 'CLOSED', 'REOPENED', 'REJECTED',
];

const doneStatuses = ['RESOLVED', 'CLOSED'];

const priorityMeta = <String, Meta>{
  'LOW': Meta('Low', Tone.gray),
  'MEDIUM': Meta('Medium', Tone.blue),
  'HIGH': Meta('High', Tone.orange),
  'CRITICAL': Meta('Critical', Tone.red),
};

const typeMeta = <String, Meta>{
  'TASK': Meta('Task', Tone.gray),
  'BUG': Meta('Bug', Tone.red),
  'FEATURE': Meta('Feature', Tone.green),
  'IMPROVEMENT': Meta('Improvement', Tone.blue),
  'SUPPORT': Meta('Support', Tone.yellow),
  'RESEARCH': Meta('Research', Tone.purple),
};

const projectStatusMeta = <String, Meta>{
  'PLANNING': Meta('Planning', Tone.gray),
  'ACTIVE': Meta('Active', Tone.green),
  'ON_HOLD': Meta('On Hold', Tone.orange),
  'COMPLETED': Meta('Completed', Tone.purple),
  'ARCHIVED': Meta('Archived', Tone.gray),
};

const roleLabels = {'ADMIN': 'Admin', 'TEAM_LEADER': 'Team Leader', 'DEVELOPER': 'Developer'};

const linkTypeLabels = {'RELATES_TO': 'relates to', 'BLOCKS': 'blocks', 'DUPLICATES': 'duplicates'};

Meta metaOf(Map<String, Meta> map, String key) => map[key] ?? Meta(key, Tone.gray);

// ── Workflow ───────────────────────────────────────────────────

/// One allowed status change. [actors]: manager | assignee | reviewer | creator
class Transition {
  final String action, label, to;
  final List<String> from, actors;
  final bool requiresReason, confirm, requiresAssignee;

  const Transition(this.action, this.label, this.from, this.to, this.actors,
      {this.requiresReason = false, this.confirm = false, this.requiresAssignee = false});
}

const transitions = <Transition>[
  Transition('triage', 'Move to New', ['BACKLOG'], 'NEW', ['manager', 'creator']),
  Transition('backlog', 'Move to Backlog', ['NEW'], 'BACKLOG', ['manager']),
  Transition('assign', 'Send to assignee', ['BACKLOG', 'NEW', 'REJECTED'], 'ASSIGNED', ['manager'], requiresAssignee: true),
  Transition('accept', 'Accept', ['ASSIGNED'], 'ACCEPTED', ['assignee']),
  Transition('reject', 'Reject', ['ASSIGNED'], 'REJECTED', ['assignee'], requiresReason: true),
  Transition('start', 'Start work', ['ACCEPTED', 'REOPENED'], 'IN_PROGRESS', ['assignee', 'manager']),
  Transition('hold', 'Put on hold', ['IN_PROGRESS', 'PENDING'], 'ON_HOLD', ['assignee', 'manager'], requiresReason: true),
  Transition('pending', 'Mark pending', ['IN_PROGRESS', 'ON_HOLD'], 'PENDING', ['assignee', 'manager'], requiresReason: true),
  Transition('resume', 'Resume work', ['ON_HOLD', 'PENDING'], 'IN_PROGRESS', ['assignee', 'manager']),
  Transition('submit', 'Submit for review', ['IN_PROGRESS'], 'IN_REVIEW', ['assignee', 'manager']),
  Transition('approve', 'Approve', ['IN_REVIEW'], 'RESOLVED', ['reviewer', 'manager']),
  Transition('request_changes', 'Request changes', ['IN_REVIEW'], 'IN_PROGRESS', ['reviewer', 'manager'], requiresReason: true),
  Transition('close', 'Close ticket', ['RESOLVED'], 'CLOSED', ['manager'], confirm: true),
  Transition('reopen', 'Reopen', ['RESOLVED', 'CLOSED'], 'REOPENED', ['manager'], requiresReason: true, confirm: true),
];

/// The workflow rule for moving from [from] to [to], or null when no such move exists.
Transition? findDefinition(String from, String to) {
  for (final t in transitions) {
    if (t.from.contains(from) && t.to == to) return t;
  }
  return null;
}

/// Statuses the user may move the ticket to (used to highlight board columns while dragging).
/// Reviewer is unknown on list items, so the server still has the final word.
Set<String> allowedTargets({
  required String status,
  required String? assigneeId,
  required String creatorId,
  required String userId,
  required bool isManager,
}) {
  final actors = <String>{
    if (isManager) 'manager',
    if (assigneeId == userId) 'assignee',
    if (creatorId == userId) 'creator',
  };
  final result = <String>{};
  for (final t in transitions) {
    if (t.from.contains(status) && t.actors.any(actors.contains) && (!t.requiresAssignee || assigneeId != null)) {
      result.add(t.to);
    }
  }
  // Managers can assign from these columns (opens the assign dialog)
  if (isManager && ['NEW', 'BACKLOG', 'REJECTED'].contains(status)) result.add('ASSIGNED');
  return result;
}
