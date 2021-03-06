library boggle;

import 'dart:math';
import 'dart:collection';

//  picks a ranfom element from an array, according to weights
int pickRandomW(Random random, Iterable<int> arr, int sumScore) {
  if (sumScore == null) {
    sumScore = arr.reduce((a, b) => a + b);
  }
  int w = random.nextInt(sumScore);
  int idx = 0;
  arr.forEach((n){
    w -= n;
    if (w < 0) return idx;
    idx++;
  });
  return idx;
}

class TrieNode {
  bool terminal = false;
  int pathCount = 0;
  final Map<int, TrieNode> children = new Map();

  child(String s) => children[s.codeUnitAt(0)];

  insertWord(String word, [int startChar = 0]) {
    if (startChar == word.length) {
      terminal = true;
      return;
    }
    int key = word.codeUnitAt(startChar);
    var child = children[key];
    if (child == null) {
      child = new TrieNode();
      children[key] = child;
    }
    child.pathCount++;
    child.insertWord(word, startChar + 1);
  }

  bool contains(String word, [int startChar = 0]) {
    if (startChar == word.length) return terminal;
    int key = word.codeUnitAt(startChar);
    var child = children[key];
    if (child == null) return false;
    return child.contains(word, startChar + 1);
  }
}

// trie data structure
class Trie {
  TrieNode root;
  get contains => root.contains;

  Trie(Iterable<String> words) {
    root = new TrieNode();
    String prevWord = "";
    for (String word in words) {
      assert(word.compareTo(prevWord) >= 0);
      root.insertWord(word);
      prevWord = word;
    }
  }

  static List<String> parseDictionary(String dict) {
    var re = new RegExp("q(?!u)");
    return dict
        .split(' ')
        .where((s) => !re.hasMatch(s))
        .map((s) => s.trim().toLowerCase().replaceAll('qu', 'q'))
        .toList()..sort();
  }
}

class Die {
  List<int> faces;
  int id;
  Die(this.faces);
}

class _Face {
  static const NUM_NEIGHBORS = 8;
  final neighbors = new List<int>(NUM_NEIGHBORS); // clockwise, from top
  int code;
  bool visited = false;

  get char => new String.fromCharCode(code);
  set char(String s) => code = s.codeUnitAt(0);
}

class Boggle {
  final int width, height, N;
  final List<_Face> faces;
  int score;

  static const OFFX = const [0, 1, 1, 1, 0, -1, -1, -1];
  static const OFFY = const [-1, -1, 0, 1, 1, 1, 0, -1];
  static offsets(int w) => [-w, -w + 1, 1, w + 1, w, w - 1, -1, -w - 1];
  static const DEFAULT_DICE = 'SGECAAREMECGNTDOYSPJNOICD';

  static final Q_CODE = "q".codeUnitAt(0);

  get letterList => faces.map((f) => f.char.toUpperCase());
  get letters => letterList.join('');

  set letterList(List<int> lst) {
    for (int i = 0; i < N; i++) faces[i].code = lst[i];
  }

  set letters(String s) {
    assert(s.length == N);
    for (int i = 0; i < N; i++) faces[i].char = s[i];
  }

  //  word rating function
  static int rate(int n) => [0, 1, 2, 3, 5, 11][max(0, min(5, n - 3))];

  // parses a dice description from text file
  static List<Die> parseDice(String desc) {
    var res = desc
        .split('\n')
        .map((s) => s.trim().split('').map((t) => t.codeUnitAt(0)).toList())
        .map((s) => new Die(s))
        .toList();
    for (int i = 0; i < res.length; i++) {
      res[i].id = i;
    }
    return res;
  }

  Boggle([String dice = null, int w = 5, int h = 5])
      : width = w, height = h, N = w * h,
        faces = new List<_Face>(w * h) {
    //  create neighbors lookup tables
    for (int i = 0; i < N; i++) {
      var face = new _Face();
      faces[i] = face;
      int x = i % w,
          y = i ~/ w;
      for (int j = 0; j < _Face.NUM_NEIGHBORS; j++) {
        int cx = x + OFFX[j], cy = y + OFFY[j];
        if (0 <= cx && cx < w && 0 <= cy && cy < h) 
          face.neighbors[j] = cx + cy * w;
      }
    }
    if (dice != null) letters = dice.toLowerCase();
  }


  //  Depth-first search inside trie/grid in parallel
  //  Callback is called on terminal nodes (full words)
  traverseBoard(trie, callback) {
    collectMatches(_Face face, TrieNode node, var path, var depth) {
      if (face.visited) return; // skip already visited faces
      var chNode = node.children[face.code];
      if (chNode == null) {
        //  prefix is not in the dictionary
        return;
      }
      //  the current prefix is in the dictionary
      if (chNode.terminal) {
        //  the prefix is also a full word
        callback(path, depth + 1);
      }
      //  go down, depth-first
      face.visited = true;
      for (int neighbor in face.neighbors) {
        if (neighbor != null) {
          path[depth + 1] = neighbor;
          collectMatches(faces[neighbor], chNode, path, depth + 1);
        }
      }
      face.visited = false;
    }

    var path = new List<int>(N + 1);
    for (int i = 0; i < N; i++) {
      path[0] = i;
      collectMatches(faces[i], trie.root, path, 0);
    }
  }

  //  inits a board randomly, using probabilistic distributions from the trie
  bool initRandom(Trie trie, List<Die> dice, int num, Random random,
      [int startCell = 0]) {
    if (num == null) num = N;

    initRandomBranch(TrieNode node, int startCell) {
      var die = dice[startCell];
      int nDieFaces = die.faces.length;
      var prob = new List<int>(nDieFaces);
      int numValid = 0;
      for (int i = 0; i < nDieFaces; i++) {
        var d = die.faces[i];
        var p = node.children[d];
        if (p == null) {
          prob[i] = 0;
        } else {
          prob[i] = p.pathCount;
          assert(p.pathCount > 0);
          numValid++;
        }
      }
      if (numValid == 0) return;
      int charIdx = pickRandomW(random, prob, null);
      var char = die.faces[charIdx];
      var face = faces[startCell];
      face.code = char;
      face.visited = true;
      num--;
      if (num == 0) return;

      //  depth-first recur into neighbors
      for (int neighbor in face.neighbors) {
        if (neighbor != null && !faces[neighbor].visited) {
          var cnode = node.children[char];
          assert(cnode != null);
          initRandomBranch(cnode, neighbor);
          if (num == 0) return;
        }
      }
    }
    initRandomBranch(trie.root, startCell);
    faces.forEach((f) => f.visited = false);
  }

  //  returns list of all matching words from a trie dictionary
  List<String> getMatchingWords(Trie trie) {
    var res = [];
    traverseBoard(trie, (path, depth) {
      var cpath = path.take(depth).toList();
      res.add(cpath.map((i) => faces[i].char).join(''));
    });
    return res;
  }

  //  returns list of all possible paths for a word
  List<List<int>> getWordPaths(String word) {
    var trie = new Trie([word]);
    var res = [];
    traverseBoard(trie, (path, depth) {
      res.add(path.take(depth).toList());
    });
    return res;
  }

  //  score with repeating words, counting "qu" as one letter
  int getRawScore(Trie trie) {
    int res = 0;
    traverseBoard(trie, (path, depth) {
      res += Boggle.rate(depth);
    });
    return res;
  }

  //  compute score for the board
  int getTotalScore(Trie trie) {
    int res = 0;
    var found = new Set<String>();
    traverseBoard(trie, (path, depth) {
      var s = path.take(depth).map((i) => faces[i].char).join('');
      if (!found.contains(s)) {
        int len = depth;

        for (var i = 0; i < depth; i++) {
          if (faces[path[i]].code == Q_CODE) len++;
        }
        res += Boggle.rate(len);
        found.add(s);
      }
    });
    return res;
  }
}