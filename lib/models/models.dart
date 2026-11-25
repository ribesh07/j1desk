// Plain data classes for the JSON returned by /api/* (same shapes as the web app's src/types).
// Dates arrive as ISO strings and are parsed to DateTime (local time).

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    (v as List? ?? const []).map((e) => f(e as Map<String, dynamic>)).toList();
double? _num(dynamic v) => v == null ? null : (v as num).toDouble();

class UserSummary {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;

  const UserSummary({required this.id, required this.name, required this.username, this.avatarUrl});

  factory UserSummary.fromJson(Map<String, dynamic> j) => UserSummary(
        id: j['id'] as String,
        name: j['name'] as String,
        username: j['username'] as String,
        avatarUrl: j['avatarUrl'] as String?,
      );

  static UserSummary? maybe(dynamic j) => j == null ? null : UserSummary.fromJson(j as Map<String, dynamic>);
}

/// Global permissions of the signed-in user (from /api/auth/me)
class Permissions {
  final bool manageUsers, manageTeams, createProjects, manageLabels, viewReports;

  const Permissions({
    this.manageUsers = false,
    this.manageTeams = false,
    this.createProjects = false,
    this.manageLabels = false,
    this.viewReports = false,
  });

  factory Permissions.fromJson(Map<String, dynamic>? j) => Permissions(
        manageUsers: j?['manageUsers'] == true,
        manageTeams: j?['manageTeams'] == true,
        createProjects: j?['createProjects'] == true,
        manageLabels: j?['manageLabels'] == true,
        viewReports: j?['viewReports'] == true,
      );
}

class User extends UserSummary {
  final String email;
  final String role; // ADMIN | TEAM_LEADER | DEVELOPER
  final String? title;
  final bool isActive;
  final Permissions permissions;
  final List<({String id, String name})> teams;
  final int openTickets;
  final int overdueTickets;

  const User({
    required super.id,
    required super.name,
    required super.username,
    super.avatarUrl,
    required this.email,
    required this.role,
    this.title,
    this.isActive = true,
    this.permissions = const Permissions(),
    this.teams = const [],
    this.openTickets = 0,
    this.overdueTickets = 0,
  });

  /// Admins and team leaders can assign, close and reopen tickets.
  bool get isManager => role == 'ADMIN' || role == 'TEAM_LEADER';
  bool get isAdmin => role == 'ADMIN';

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as String,
        name: j['name'] as String,
        username: j['username'] as String,
        avatarUrl: j['avatarUrl'] as String?,
        email: j['email'] as String? ?? '',
        role: j['role'] as String? ?? 'DEVELOPER',
        title: j['title'] as String?,
        isActive: j['isActive'] != false,
        permissions: Permissions.fromJson(j['permissions'] as Map<String, dynamic>?),
        teams: (j['teams'] as List? ?? const [])
            .map((t) => (id: t['id'] as String, name: t['name'] as String))
            .toList(),
        openTickets: (j['openTickets'] as num?)?.toInt() ?? 0,
        overdueTickets: (j['overdueTickets'] as num?)?.toInt() ?? 0,
      );
}

class Label {
  final String id;
  final String name;
  final String color; // hex like #d73a4a
  final String? description;

  const Label({required this.id, required this.name, required this.color, this.description});

  factory Label.fromJson(Map<String, dynamic> j) => Label(
        id: j['id'] as String,
        name: j['name'] as String,
        color: j['color'] as String,
        description: j['description'] as String?,
      );
}

class Team {
  final String id;
  final String name;
  final String? description;
  final UserSummary? leader;
  final List<UserSummary> members;
  final int projectCount;

  const Team({required this.id, required this.name, this.description, this.leader, this.members = const [], this.projectCount = 0});

  factory Team.fromJson(Map<String, dynamic> j) => Team(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        leader: UserSummary.maybe(j['leader']),
        members: _list(j['members'], UserSummary.fromJson),
        projectCount: (j['projectCount'] as num?)?.toInt() ?? 0,
      );
}

class ProjectStats {
  final int total, completed, inProgress, pending, overdue, progress;

  const ProjectStats({this.total = 0, this.completed = 0, this.inProgress = 0, this.pending = 0, this.overdue = 0, this.progress = 0});

  factory ProjectStats.fromJson(Map<String, dynamic>? j) => ProjectStats(
        total: (j?['total'] as num?)?.toInt() ?? 0,
        completed: (j?['completed'] as num?)?.toInt() ?? 0,
        inProgress: (j?['inProgress'] as num?)?.toInt() ?? 0,
        pending: (j?['pending'] as num?)?.toInt() ?? 0,
        overdue: (j?['overdue'] as num?)?.toInt() ?? 0,
        progress: (j?['progress'] as num?)?.toInt() ?? 0,
      );
}

class Project {
  final String id, name, key, status, priority;
  final String? description;
  final DateTime? startDate, dueDate, archivedAt;
  final UserSummary owner;
  final ({String id, String name})? team;
  final List<UserSummary> members;
  final ProjectStats stats;
  final bool canEdit, canDelete, canManageMembers;

  const Project({
    required this.id,
    required this.name,
    required this.key,
    required this.status,
    required this.priority,
    this.description,
    this.startDate,
    this.dueDate,
    this.archivedAt,
    required this.owner,
    this.team,
    this.members = const [],
    this.stats = const ProjectStats(),
    this.canEdit = false,
    this.canDelete = false,
    this.canManageMembers = false,
  });

  factory Project.fromJson(Map<String, dynamic> j) {
    final perms = j['permissions'] as Map<String, dynamic>?;
    final team = j['team'] as Map<String, dynamic>?;
    return Project(
      id: j['id'] as String,
      name: j['name'] as String,
      key: j['key'] as String,
      status: j['status'] as String,
      priority: j['priority'] as String,
      description: j['description'] as String?,
      startDate: _date(j['startDate']),
      dueDate: _date(j['dueDate']),
      archivedAt: _date(j['archivedAt']),
      owner: UserSummary.fromJson(j['owner'] as Map<String, dynamic>),
      team: team == null ? null : (id: team['id'] as String, name: team['name'] as String),
      members: _list(j['members'], UserSummary.fromJson),
      stats: ProjectStats.fromJson(j['stats'] as Map<String, dynamic>?),
      canEdit: perms?['canEdit'] == true,
      canDelete: perms?['canDelete'] == true,
      canManageMembers: perms?['canManageMembers'] == true,
    );
  }
}

/// Short reference to a ticket (parent, subtask, link, notification)
class TicketRef {
  final String id, key, title;
  final String? status;
  final UserSummary? assignee;

  const TicketRef({required this.id, required this.key, required this.title, this.status, this.assignee});

  factory TicketRef.fromJson(Map<String, dynamic> j) => TicketRef(
        id: j['id'] as String? ?? '',
        key: j['key'] as String,
        title: j['title'] as String,
        status: j['status'] as String?,
        assignee: UserSummary.maybe(j['assignee']),
      );
}

/// Ticket as returned by GET /api/tickets (list + board)
class Ticket {
  final String id, key, title, type, status, priority;
  final int number;
  final double position;
  final ({String id, String key, String name}) project;
  final UserSummary? assignee;
  final UserSummary creator;
  final List<Label> labels;
  final DateTime? dueDate;
  final bool isOverdue;
  final int commentCount, attachmentCount, subtaskCount;
  final DateTime createdAt, updatedAt;

  const Ticket({
    required this.id,
    required this.key,
    required this.title,
    required this.type,
    required this.status,
    required this.priority,
    required this.number,
    required this.position,
    required this.project,
    this.assignee,
    required this.creator,
    this.labels = const [],
    this.dueDate,
    this.isOverdue = false,
    this.commentCount = 0,
    this.attachmentCount = 0,
    this.subtaskCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Ticket.fromJson(Map<String, dynamic> j) {
    final p = j['project'] as Map<String, dynamic>;
    return Ticket(
      id: j['id'] as String,
      key: j['key'] as String,
      title: j['title'] as String,
      type: j['type'] as String,
      status: j['status'] as String,
      priority: j['priority'] as String,
      number: (j['number'] as num).toInt(),
      position: (j['position'] as num).toDouble(),
      project: (id: p['id'] as String, key: p['key'] as String, name: p['name'] as String),
      assignee: UserSummary.maybe(j['assignee']),
      creator: UserSummary.fromJson(j['creator'] as Map<String, dynamic>),
      labels: _list(j['labels'], Label.fromJson),
      dueDate: _date(j['dueDate']),
      isOverdue: j['isOverdue'] == true,
      commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
      attachmentCount: (j['attachmentCount'] as num?)?.toInt() ?? 0,
      subtaskCount: (j['subtaskCount'] as num?)?.toInt() ?? 0,
      createdAt: _date(j['createdAt']) ?? DateTime.now(),
      updatedAt: _date(j['updatedAt']) ?? DateTime.now(),
    );
  }

  /// Copy used by the board for optimistic moves.
  Ticket copyWith({String? status, double? position}) => Ticket(
        id: id,
        key: key,
        title: title,
        type: type,
        status: status ?? this.status,
        priority: priority,
        number: number,
        position: position ?? this.position,
        project: project,
        assignee: assignee,
        creator: creator,
        labels: labels,
        dueDate: dueDate,
        isOverdue: isOverdue,
        commentCount: commentCount,
        attachmentCount: attachmentCount,
        subtaskCount: subtaskCount,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// A workflow action the current user may perform (permissions.transitions)
class TransitionOption {
  final String action, label, to;
  final bool requiresReason, confirm;

  const TransitionOption({required this.action, required this.label, required this.to, this.requiresReason = false, this.confirm = false});

  factory TransitionOption.fromJson(Map<String, dynamic> j) => TransitionOption(
        action: j['action'] as String,
        label: j['label'] as String,
        to: j['to'] as String,
        requiresReason: j['requiresReason'] == true,
        confirm: j['confirm'] == true,
      );
}

class Attachment {
  final String id, fileName, mimeType, downloadUrl;
  final int size;
  final UserSummary uploader;
  final DateTime createdAt;
  final bool canDelete;

  const Attachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.downloadUrl,
    required this.size,
    required this.uploader,
    required this.createdAt,
    this.canDelete = false,
  });

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        id: j['id'] as String,
        fileName: j['fileName'] as String,
        mimeType: j['mimeType'] as String,
        downloadUrl: j['downloadUrl'] as String,
        size: (j['size'] as num).toInt(),
        uploader: UserSummary.fromJson(j['uploader'] as Map<String, dynamic>),
        createdAt: _date(j['createdAt']) ?? DateTime.now(),
        canDelete: j['canDelete'] == true,
      );
}

class TicketLinkItem {
  final String id, type, direction; // direction: outgoing | incoming
  final TicketRef ticket;

  const TicketLinkItem({required this.id, required this.type, required this.direction, required this.ticket});

  factory TicketLinkItem.fromJson(Map<String, dynamic> j) => TicketLinkItem(
        id: j['id'] as String,
        type: j['type'] as String,
        direction: j['direction'] as String,
        ticket: TicketRef.fromJson(j['ticket'] as Map<String, dynamic>),
      );
}

/// Full ticket from GET /api/tickets/:key
class TicketDetail {
  final Ticket ticket;
  final String? description;
  final UserSummary? reviewer;
  final ({String id, String name})? team;
  final double? estimateHours, actualHours;
  final DateTime? resolvedAt, closedAt, deletedAt;
  final TicketRef? parent;
  final List<TicketRef> subtasks;
  final List<TicketLinkItem> links;
  final List<Attachment> attachments;
  final bool canEdit, canAssign, canArchive, canComment, canUpload;
  final List<TransitionOption> transitions;

  const TicketDetail({
    required this.ticket,
    this.description,
    this.reviewer,
    this.team,
    this.estimateHours,
    this.actualHours,
    this.resolvedAt,
    this.closedAt,
    this.deletedAt,
    this.parent,
    this.subtasks = const [],
    this.links = const [],
    this.attachments = const [],
    this.canEdit = false,
    this.canAssign = false,
    this.canArchive = false,
    this.canComment = false,
    this.canUpload = false,
    this.transitions = const [],
  });

  factory TicketDetail.fromJson(Map<String, dynamic> j) {
    final perms = j['permissions'] as Map<String, dynamic>? ?? const {};
    final team = j['team'] as Map<String, dynamic>?;
    return TicketDetail(
      ticket: Ticket.fromJson(j),
      description: j['description'] as String?,
      reviewer: UserSummary.maybe(j['reviewer']),
      team: team == null ? null : (id: team['id'] as String, name: team['name'] as String),
      estimateHours: _num(j['estimateHours']),
      actualHours: _num(j['actualHours']),
      resolvedAt: _date(j['resolvedAt']),
      closedAt: _date(j['closedAt']),
      deletedAt: _date(j['deletedAt']),
      parent: j['parent'] == null ? null : TicketRef.fromJson(j['parent'] as Map<String, dynamic>),
      subtasks: _list(j['subtasks'], TicketRef.fromJson),
      links: _list(j['links'], TicketLinkItem.fromJson),
      attachments: _list(j['attachments'], Attachment.fromJson),
      canEdit: perms['canEdit'] == true,
      canAssign: perms['canAssign'] == true,
      canArchive: perms['canArchive'] == true,
      canComment: perms['canComment'] == true,
      canUpload: perms['canUpload'] == true,
      transitions: _list(perms['transitions'], TransitionOption.fromJson),
    );
  }
}

class Comment {
  final String id, body;
  final UserSummary author;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool canEdit, canDelete;

  const Comment({required this.id, required this.body, required this.author, required this.createdAt, this.editedAt, this.canEdit = false, this.canDelete = false});

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'] as String,
        body: j['body'] as String,
        author: UserSummary.fromJson(j['author'] as Map<String, dynamic>),
        createdAt: _date(j['createdAt']) ?? DateTime.now(),
        editedAt: _date(j['editedAt']),
        canEdit: j['canEdit'] == true,
        canDelete: j['canDelete'] == true,
      );
}

/// Entry of a ticket's (or project's) activity log
class Activity {
  final String id, type;
  final UserSummary actor;
  final String? fromValue, toValue, message;
  final DateTime createdAt;
  final ({String key, String title})? ticket; // only in dashboard / project activity

  const Activity({required this.id, required this.type, required this.actor, this.fromValue, this.toValue, this.message, required this.createdAt, this.ticket});

  factory Activity.fromJson(Map<String, dynamic> j) {
    final t = j['ticket'] as Map<String, dynamic>?;
    return Activity(
      id: j['id'] as String,
      type: j['type'] as String,
      actor: UserSummary.fromJson(j['actor'] as Map<String, dynamic>),
      fromValue: j['fromValue'] as String?,
      toValue: j['toValue'] as String?,
      message: j['message'] as String?,
      createdAt: _date(j['createdAt']) ?? DateTime.now(),
      ticket: t == null ? null : (key: t['key'] as String, title: t['title'] as String),
    );
  }
}

/// Entry of GET /api/tickets/:id/assignments
class Assignment {
  final String id;
  final UserSummary? from, to;
  final UserSummary assignedBy;
  final String? reason;
  final DateTime createdAt;

  const Assignment({required this.id, this.from, this.to, required this.assignedBy, this.reason, required this.createdAt});

  factory Assignment.fromJson(Map<String, dynamic> j) => Assignment(
        id: j['id'] as String,
        from: UserSummary.maybe(j['from']),
        to: UserSummary.maybe(j['to']),
        assignedBy: UserSummary.fromJson(j['assignedBy'] as Map<String, dynamic>),
        reason: j['reason'] as String?,
        createdAt: _date(j['createdAt']) ?? DateTime.now(),
      );
}

class AppNotification {
  final String id, type, title;
  final String? body;
  final UserSummary? actor;
  final TicketRef? ticket;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({required this.id, required this.type, required this.title, this.body, this.actor, this.ticket, this.readAt, required this.createdAt});

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        type: j['type'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        actor: UserSummary.maybe(j['actor']),
        ticket: j['ticket'] == null ? null : TicketRef.fromJson(j['ticket'] as Map<String, dynamic>),
        readAt: _date(j['readAt']),
        createdAt: _date(j['createdAt']) ?? DateTime.now(),
      );

  AppNotification markRead() =>
      AppNotification(id: id, type: type, title: title, body: body, actor: actor, ticket: ticket, readAt: DateTime.now(), createdAt: createdAt);
}

/// Paginated list: { items, total, page, pageSize, totalPages }
class Paged<T> {
  final List<T> items;
  final int total, page, pageSize, totalPages;

  const Paged({required this.items, required this.total, required this.page, required this.pageSize, required this.totalPages});

  factory Paged.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) f) => Paged(
        items: _list(j['items'], f),
        total: (j['total'] as num).toInt(),
        page: (j['page'] as num).toInt(),
        pageSize: (j['pageSize'] as num).toInt(),
        totalPages: (j['totalPages'] as num).toInt(),
      );
}

/// { key, label, count } used by charts
class CountItem {
  final String key, label;
  final int count;

  const CountItem(this.key, this.label, this.count);

  factory CountItem.fromJson(Map<String, dynamic> j) =>
      CountItem(j['key'] as String, j['label'] as String, (j['count'] as num).toInt());
}

/// GET /api/reports/dashboard
class DashboardData {
  final Map<String, int> cards;
  final List<CountItem> byStatus, byPriority;
  final List<Ticket> myUpcoming, overdue;
  final List<Activity> recentActivity;
  final List<({String id, String key, String name, int progress, int total, int completed})> projects;
  final List<({UserSummary user, int open, int inProgress, int overdue})>? workload;

  const DashboardData({
    required this.cards,
    required this.byStatus,
    required this.byPriority,
    required this.myUpcoming,
    required this.overdue,
    required this.recentActivity,
    required this.projects,
    this.workload,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
        cards: (j['cards'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt())),
        byStatus: _list(j['byStatus'], CountItem.fromJson),
        byPriority: _list(j['byPriority'], CountItem.fromJson),
        myUpcoming: _list(j['myUpcoming'], Ticket.fromJson),
        overdue: _list(j['overdue'], Ticket.fromJson),
        recentActivity: _list(j['recentActivity'], Activity.fromJson),
        projects: (j['projects'] as List? ?? const [])
            .map((p) => (
                  id: p['id'] as String,
                  key: p['key'] as String,
                  name: p['name'] as String,
                  progress: (p['progress'] as num).toInt(),
                  total: (p['total'] as num).toInt(),
                  completed: (p['completed'] as num).toInt(),
                ))
            .toList(),
        workload: (j['workload'] as List?)
            ?.map((w) => (
                  user: UserSummary.fromJson(w['user'] as Map<String, dynamic>),
                  open: (w['open'] as num).toInt(),
                  inProgress: (w['inProgress'] as num).toInt(),
                  overdue: (w['overdue'] as num).toInt(),
                ))
            .toList(),
      );
}

/// GET /api/reports/tickets
class TicketReport {
  final Map<String, int> totals;
  final List<CountItem> byStatus, byPriority;
  final List<({String key, String label, int count, int completed})> byProject;
  final List<({UserSummary user, int assigned, int completed, int open, int overdue})> byMember;
  final List<({String date, int created, int completed})> timeline;

  const TicketReport({
    required this.totals,
    required this.byStatus,
    required this.byPriority,
    required this.byProject,
    required this.byMember,
    required this.timeline,
  });

  factory TicketReport.fromJson(Map<String, dynamic> j) => TicketReport(
        totals: (j['totals'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt())),
        byStatus: _list(j['byStatus'], CountItem.fromJson),
        byPriority: _list(j['byPriority'], CountItem.fromJson),
        byProject: (j['byProject'] as List? ?? const [])
            .map((p) => (
                  key: p['key'] as String,
                  label: p['label'] as String,
                  count: (p['count'] as num).toInt(),
                  completed: (p['completed'] as num).toInt(),
                ))
            .toList(),
        byMember: (j['byMember'] as List? ?? const [])
            .map((m) => (
                  user: UserSummary.fromJson(m['user'] as Map<String, dynamic>),
                  assigned: (m['assigned'] as num).toInt(),
                  completed: (m['completed'] as num).toInt(),
                  open: (m['open'] as num).toInt(),
                  overdue: (m['overdue'] as num).toInt(),
                ))
            .toList(),
        timeline: (j['timeline'] as List? ?? const [])
            .map((t) => (
                  date: t['date'] as String,
                  created: (t['created'] as num).toInt(),
                  completed: (t['completed'] as num).toInt(),
                ))
            .toList(),
      );
}
