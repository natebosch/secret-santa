import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:math';

import 'package:angular2/angular2.dart';
import 'package:angular2/bootstrap.dart';

final random = new Random(new DateTime.now().year);

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
    return JSON.decode(namesJson);
  }

  Future<List<String>> _shuffledNames;
  Future<List<String>> get shuffledNames => _shuffledNames ??= shuffleNames();

  Future<List<String>> shuffleNames() async {
    var shuffled = await participants;
    var resolvedGroups = await groups;
    shuffled.shuffle(random);
    // Ensure no disallowed neighbors
    int problemIndex = indexOfFirstBadMatch(shuffled, resolvedGroups);
    int swapCount = 0;
    while (problemIndex > 0) {
      swapCount++;
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

@Component(
    selector: 'secret-santa',
    template: r'''
  <name-list (nameChange)="name=$event" [names]="names" *ngIf="!nameChosen">
  </name-list>
  <giftee *ngIf="nameChosen" [from]="name">
  </giftee>
''',
    providers: const[NameService],
    directives: const[NameList, Giftee, NgIf]
)
class SecretSanta {
  String name;

  bool get nameChosen => name != null;
  List<String> names;

  SecretSanta(NameService nameService) {
    nameService.participants.then((participants) {
      names = participants;
    });
  }
}

@Component(
    selector: 'name-list',
    template: '''
Who are you? (be honest!)
<p *ngFor="#name of names"><a href="" (click)="choose(name)">{{name}}</a></p>''',
    directives: const [NgFor]
)
class NameList {
  @Input()
  List<String> names;

  @Output()
  final nameChange = new EventEmitter<String>();

  bool choose(String choice) {
    nameChange.add(choice);
    return false;
  }
}

@Component(
    selector: 'giftee',
    template: '''Hey {{from}}, You should get a gift for {{giftee}}''')
class Giftee {
  var _fromCompleter = new Completer<String>();

  @Input()
  void set from(String from) {
    _fromCompleter.complete(from);
  }

  String _from;

  String get from => _from;

  String giftee;

  Giftee(NameService nameService) {
    Future.wait([_fromCompleter.future, nameService.shuffledNames])
        .then((results) {
      _from = results[0];
      var shuffled = results[1];
      var giverIndex = shuffled.indexOf(from);
      var next = giverIndex + 1 >= shuffled.length ? 0 : giverIndex + 1;
      giftee = shuffled[next];
    });
  }
}

void main() {
  bootstrap(SecretSanta);
}
