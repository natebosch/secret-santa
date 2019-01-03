import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:math';

import 'package:angular/angular.dart';
import 'package:angular_router/angular_router.dart';

import 'main.template.dart' as self;

@GenerateInjector(routerProvidersHash)
final injector = self.injector$Injector;

void main() {
  runApp(self.SecretSantaNgFactory, createInjector: injector);
}

@Injectable()
class NameService {
  Future<Map<String, List<List<String>>>> _data;
  Future<Map<String, List<List<String>>>> get data => _data ??= loadGroups();

  Future<List<String>> get groups async => (await data).keys.toList();

  Future<List<String>> participants(String name) async {
    var resolvedGroups = await data;
    return resolvedGroups[name].expand((group) => group).toList();
  }

  Future<Map<String, List<List<String>>>> loadGroups() async {
    const path = 'resources/names.json';
    var namesJson = await HttpRequest.getString(path);
    return Map<String, List<List<String>>>.from((jsonDecode(namesJson) as Map)
        .map((name, groups) => MapEntry(
            name,
            List<List<String>>.from(
                (groups as Iterable).map((l) => List<String>.from(l))))));
  }

  final _shuffledNames = <String, Future<List<String>>>{};
  Future<List<String>> shuffledNames(String name, int year) =>
      _shuffledNames.putIfAbsent(name, () => _shuffleNames(name, year));

  /// Shuffle the names such that no names in a group end up as neighbors.
  Future<List<String>> _shuffleNames(String name, int year) async {
    var shuffled = await participants(name);
    var resolvedGroups = (await data)[name];
    final random = Random(year ?? DateTime.now().year);
    shuffled.shuffle(random);
    // Ensure no disallowed neighbors
    int problemIndex = indexOfFirstBadMatch(shuffled, resolvedGroups);
    while (problemIndex >= 0) {
      int swapWith = random.nextInt(shuffled.length);
      var temp = shuffled[problemIndex];
      shuffled[problemIndex] = shuffled[swapWith];
      shuffled[swapWith] = temp;
      problemIndex = indexOfFirstBadMatch(shuffled, resolvedGroups);
    }
    return shuffled;
  }

  int indexOfFirstBadMatch(
      List<String> participants, List<List<String>> groups) {
    for (int i = 0; i < participants.length; i++) {
      var participant = participants[i];
      var group = groups.firstWhere((group) => group.contains(participant));
      var matchIndex = i + 1 >= participants.length ? 0 : i + 1;
      if (group.contains(participants[matchIndex])) {
        return matchIndex;
      }
    }
    return -1;
  }
}

class RoutePaths {
  static final groups = RoutePath(path: '/');
  static final names = RoutePath(path: '/:group/names');
  static final giftee = RoutePath(path: '/:group/from/:name');
}

class Routes {
  static final groups = RouteDefinition(
      routePath: RoutePaths.groups,
      component: self.GroupListNgFactory,
      useAsDefault: true);
  static final names = RouteDefinition(
    routePath: RoutePaths.names,
    component: self.NameListNgFactory,
  );
  static final giftee = RouteDefinition(
      routePath: RoutePaths.giftee, component: self.GifteeNgFactory);
  static final all = [groups, names, giftee];
}

@Component(
    selector: 'secret-santa',
    template: '''
    <h1> Secret Santa</h1>
    <router-outlet [routes]="Routes.all"></router-outlet>
''',
    providers: const [NameService],
    directives: const [RouterOutlet],
    exports: [Routes])
class SecretSanta {
  List<String> names;

  SecretSanta(NameService nameService) {}
}

@Component(selector: 'group-list', template: '''
Which group?
<p *ngFor="let group of groups">
  <a [routerLink]="pathFor(group)">
    {{group}}
  </a>
</p>''', directives: const [RouterLink, NgFor], exports: [RoutePaths])
class GroupList {
  List<String> groups;

  GroupList(NameService nameService) {
    () async {
      groups = await nameService.groups;
    }();
  }

  String pathFor(String group) =>
      RoutePaths.names.toUrl(parameters: {'group': group});
}

@Component(selector: 'name-list', template: '''
Who are you? (be honest!)
<p *ngFor="let name of names">
  <a [routerLink]="pathFor(name)">
    {{name}}
  </a>
</p>''', directives: const [RouterLink, NgFor], exports: [RoutePaths])
class NameList implements OnActivate {
  final NameService _nameService;
  List<String> names;
  String _group;

  NameList(this._nameService);

  String pathFor(String name) =>
      RoutePaths.giftee.toUrl(parameters: {'group': _group, 'name': name});

  @override
  void onActivate(_, RouterState current) async {
    _group = current.parameters['group'];
    names = await _nameService.participants(_group);
  }
}

@Component(
    selector: 'giftee',
    template: '''Hey {{from}}, You should get a gift for {{giftee}}''')
class Giftee implements OnActivate {
  String from;
  String giftee;
  final NameService _nameService;

  Giftee(this._nameService);

  @override
  void onActivate(_, RouterState current) async {
    from = current.parameters['name'];
    final group = current.parameters['group'];
    final shuffledNames = await _nameService.shuffledNames(
        group, int.tryParse(current.queryParameters['year'] ?? ''));
    final giverIndex = shuffledNames.indexOf(from);
    final next = giverIndex + 1 >= shuffledNames.length ? 0 : giverIndex + 1;
    giftee = shuffledNames[next];
  }
}
