import 'package:flutter_bloc/flutter_bloc.dart';

/// Sections of the left drawer (same as the web sidebar).
enum Section { overview, myTasks, inbox, projects, tickets, team, reports, settings }

/// What the shell shows: the drawer section, an open project (inside "Projects"),
/// the team filter of the drawer's project list, and whether the wide sidebar is collapsed.
class NavState {
  final Section section;
  final String? projectKey;
  final String? teamId;
  final bool collapsed;

  const NavState(this.section, {this.projectKey, this.teamId, this.collapsed = false});

  NavState copy({Section? section, String? projectKey, bool clearProject = false, String? teamId, bool clearTeam = false, bool? collapsed}) =>
      NavState(
        section ?? this.section,
        projectKey: clearProject ? null : (projectKey ?? this.projectKey),
        teamId: clearTeam ? null : (teamId ?? this.teamId),
        collapsed: collapsed ?? this.collapsed,
      );
}

class NavCubit extends Cubit<NavState> {
  NavCubit() : super(const NavState(Section.overview));

  /// Opens a drawer section (closes any open project).
  void open(Section s) => emit(state.copy(section: s, clearProject: true));

  /// Opens a project's board inside the Projects section; null goes back to the list.
  void openProject(String? key) =>
      emit(key == null ? state.copy(section: Section.projects, clearProject: true) : state.copy(section: Section.projects, projectKey: key));

  /// Filters the drawer's project list by team (null = all teams).
  void setTeam(String? id) => emit(id == null ? state.copy(clearTeam: true) : state.copy(teamId: id));

  void toggleCollapsed() => emit(state.copy(collapsed: !state.collapsed));
}
