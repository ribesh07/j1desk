import 'dart:typed_data';

import '../models/models.dart';
import 'api_client.dart';

/// All REST endpoints used by the app (same API as the web app, see /api/docs).
/// Each function returns parsed models; errors are thrown as [ApiException].
class Api {
  static ApiClient get _c => ApiClient.instance;

  // ── Auth ────────────────────────────────────────────────────
  /// POST /api/auth/login → saves the bearer token and returns the user.
  static Future<User> login(String email, String password) async {
    final data = await _c.post('/auth/login', {'email': email, 'password': password});
    await _c.saveToken(data['token'] as String);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  static Future<User> me() async => User.fromJson(await _c.get('/auth/me') as Map<String, dynamic>);

  static Future<void> logout() async {
    try {
      await _c.post('/auth/logout');
    } finally {
      await _c.saveToken(null);
    }
  }

  static Future<void> changePassword(String current, String next) =>
      _c.post('/auth/change-password', {'currentPassword': current, 'newPassword': next, 'confirmPassword': next});

  // ── Push devices ────────────────────────────────────────────
  static Future<void> registerDevice(String token, String platform) =>
      _c.post('/devices', {'token': token, 'platform': platform});
  static Future<void> removeDevice(String token) => _c.delete('/devices', {'token': token});

  // ── Projects ────────────────────────────────────────────────
  static Future<List<Project>> projects({String? q, bool includeArchived = false}) async {
    final data = await _c.get('/projects', {'q': q, if (includeArchived) 'includeArchived': 'true'});
    return (data as List).map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Project> project(String idOrKey) async =>
      Project.fromJson(await _c.get('/projects/$idOrKey') as Map<String, dynamic>);

  static Future<Project> createProject(Map<String, dynamic> body) async =>
      Project.fromJson(await _c.post('/projects', body) as Map<String, dynamic>);

  static Future<Project> updateProject(String id, Map<String, dynamic> body) async =>
      Project.fromJson(await _c.patch('/projects/$id', body) as Map<String, dynamic>);

  static Future<Paged<Activity>> projectActivity(String id, {int page = 1}) async => Paged.fromJson(
      await _c.get('/projects/$id/activity', {'page': page, 'pageSize': 30}) as Map<String, dynamic>, Activity.fromJson);

  // ── Tickets ─────────────────────────────────────────────────
  /// GET /api/tickets with filters: projectId, status (comma list), priority, type,
  /// assigneeId (id | me | none), q, overdue, sort, order, page, pageSize.
  static Future<Paged<Ticket>> tickets(Map<String, dynamic> query) async =>
      Paged.fromJson(await _c.get('/tickets', query) as Map<String, dynamic>, Ticket.fromJson);

  static Future<TicketDetail> ticket(String idOrKey) async =>
      TicketDetail.fromJson(await _c.get('/tickets/$idOrKey') as Map<String, dynamic>);

  static Future<TicketDetail> createTicket(Map<String, dynamic> body) async =>
      TicketDetail.fromJson(await _c.post('/tickets', body) as Map<String, dynamic>);

  static Future<TicketDetail> updateTicket(String id, Map<String, dynamic> body) async =>
      TicketDetail.fromJson(await _c.patch('/tickets/$id', body) as Map<String, dynamic>);

  static Future<void> archiveTicket(String id) => _c.delete('/tickets/$id');

  static Future<TicketDetail> restoreTicket(String id) async =>
      TicketDetail.fromJson(await _c.post('/tickets/$id/restore') as Map<String, dynamic>);

  /// Workflow status change (server validates and notifies the team by push).
  static Future<TicketDetail> changeStatus(String id, String status, {String? reason}) async =>
      TicketDetail.fromJson(await _c.post('/tickets/$id/status', {'status': status, if (reason != null) 'reason': reason}) as Map<String, dynamic>);

  /// Kanban drag & drop: new column (status) + position inside the column.
  static Future<TicketDetail> moveTicket(String id, String status, double position, {String? reason}) async =>
      TicketDetail.fromJson(await _c.post('/tickets/$id/move', {'status': status, 'position': position, if (reason != null) 'reason': reason})
          as Map<String, dynamic>);

  /// Assign (assigneeId) or unassign (null)
  static Future<TicketDetail> assignTicket(String id, String? assigneeId, {String? reason}) async =>
      TicketDetail.fromJson(await _c.post('/tickets/$id/assign', {'assigneeId': assigneeId, if (reason != null) 'reason': reason})
          as Map<String, dynamic>);

  static Future<List<Comment>> comments(String id) async =>
      (await _c.get('/tickets/$id/comments') as List).map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();

  static Future<void> addComment(String id, String body) => _c.post('/tickets/$id/comments', {'body': body});
  static Future<void> editComment(String id, String commentId, String body) =>
      _c.patch('/tickets/$id/comments/$commentId', {'body': body});
  static Future<void> deleteComment(String id, String commentId) => _c.delete('/tickets/$id/comments/$commentId');

  static Future<List<Activity>> ticketActivity(String id) async =>
      (await _c.get('/tickets/$id/activity') as List).map((e) => Activity.fromJson(e as Map<String, dynamic>)).toList();

  static Future<List<Assignment>> assignments(String id) async =>
      (await _c.get('/tickets/$id/assignments') as List).map((e) => Assignment.fromJson(e as Map<String, dynamic>)).toList();

  static Future<void> uploadAttachments(String id, List<({String name, Uint8List bytes})> files) =>
      _c.upload('/tickets/$id/attachments', files);
  static Future<void> deleteAttachment(String attachmentId) => _c.delete('/attachments/$attachmentId');
  static Future<Uint8List> downloadAttachment(Attachment a) => _c.download(a.downloadUrl);

  static Future<void> addLink(String id, String ticketKey, String type) =>
      _c.post('/tickets/$id/links', {'ticketKey': ticketKey, 'type': type});
  static Future<void> removeLink(String id, String linkId) => _c.delete('/tickets/$id/links/$linkId');

  // ── People ──────────────────────────────────────────────────
  /// Users; pass projectId to get only people who can work on that project.
  static Future<List<User>> users({String? projectId, String? q}) async =>
      (await _c.get('/users', {'projectId': projectId, 'q': q}) as List)
          .map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList();

  static Future<List<Team>> teams() async =>
      (await _c.get('/teams') as List).map((e) => Team.fromJson(e as Map<String, dynamic>)).toList();

  static Future<List<Label>> labels() async =>
      (await _c.get('/labels') as List).map((e) => Label.fromJson(e as Map<String, dynamic>)).toList();

  // ── Notifications ───────────────────────────────────────────
  static Future<({Paged<AppNotification> page, int unread})> notifications({int page = 1, bool unreadOnly = false}) async {
    final data = await _c.get('/notifications', {'page': page, 'pageSize': 30, if (unreadOnly) 'unread': 'true'})
        as Map<String, dynamic>;
    return (page: Paged.fromJson(data, AppNotification.fromJson), unread: (data['unreadCount'] as num).toInt());
  }

  static Future<int> unreadCount() async => ((await _c.get('/notifications/unread-count'))['count'] as num).toInt();
  static Future<void> markRead(String id) => _c.post('/notifications/$id/read');
  static Future<void> markAllRead() => _c.post('/notifications/read-all');

  // ── Reports & search ────────────────────────────────────────
  static Future<DashboardData> dashboard() async =>
      DashboardData.fromJson(await _c.get('/reports/dashboard') as Map<String, dynamic>);

  static Future<TicketReport> ticketReport({String? from, String? to, String? projectId}) async => TicketReport.fromJson(
      await _c.get('/reports/tickets', {'from': from, 'to': to, 'projectId': projectId}) as Map<String, dynamic>);

  /// Global search: tickets, projects and people
  static Future<Map<String, dynamic>> search(String q) async => await _c.get('/search', {'q': q}) as Map<String, dynamic>;
}
