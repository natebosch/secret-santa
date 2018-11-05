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
  Future<List<List<String>>> _groups;

  Future<List<List<String>>> get groups => _groups ??= loadGroups();

  Future<List<String>> get participants async {
    var resolvedGroups = await groups;
    return resolvedGroups.expand((group) => group).toList();
  }

  Future<List<List<String>>> loadGroups() async {
    const path = '/resources/names.json';
    var namesJson = await HttpRequest.getString(path);
    return List<List<String>>.from(
        (jsonDecode(namesJson) as Iterable).map((l) => List<String>.from(l)));
  }

  Future<List<String>> _shuffledNames;
  Future<List<String>> get shuffledNames => _shuffledNames ??= _shuffleNames();

  /// Shuffle the names such that no names in a group end up as neighbors.
  Future<List<String>> _shuffleNames() async {
    var shuffled = await participants;
    var resolvedGroups = await groups;
    final random = new Random(new DateTime.now().year);
    shuffled.shuffle(random);
    // Ensure no disallowed neighbors
    int problemIndex = indexOfFirstBadMatch(shuffled, resolvedGroups);
    while (problemIndex > 0) {
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
  static final names = RoutePath(path: '/');
  static final giftee = RoutePath(path: '/from/:name');
}

class Routes {
  static final names = RouteDefinition(
      routePath: RoutePaths.names,
      component: self.NameListNgFactory,
      useAsDefault: true);
  static final giftee = RouteDefinition(
      routePath: RoutePaths.giftee, component: self.GifteeNgFactory);
  static final all = [names, giftee];
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

@Component(selector: 'name-list', template: '''
Who are you? (be honest!)
<p *ngFor="let name of names">
  <a [routerLink]="pathFor(name)">
    {{name}}
  </a>
</p>''', directives: const [RouterLink, NgFor], exports: [RoutePaths])
class NameList {
  List<String> names;

  NameList(NameService nameService) {
    nameService.participants.then((participants) {
      names = participants;
    });
  }

  String pathFor(String name) =>
      RoutePaths.giftee.toUrl(parameters: {'name': name});
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
    final shuffledNames = await _nameService.shuffledNames;
    final giverIndex = shuffledNames.indexOf(from);
    final next = giverIndex + 1 >= shuffledNames.length ? 0 : giverIndex + 1;
    giftee = shuffledNames[next];
  }
}
