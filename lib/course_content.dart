/// Parse a whole module before displaying it. A malformed quiz must not become
/// an easier, shorter quiz by silently dropping the broken questions.
List<Map<String, String>> parseFlashcards(
  Iterable<Map<String, dynamic>> documents,
) =>
    documents.map((data) {
      final term = data['question'];
      final definition = data['answer'];
      if (term is! String ||
          term.trim().isEmpty ||
          definition is! String ||
          definition.trim().isEmpty) {
        throw const FormatException('Incomplete flashcard');
      }
      return {
        'term': term.trim(),
        'definition': definition.trim(),
        'label': 'Flashcard',
        'example': data['example'] is String ? data['example'] as String : '',
      };
    }).toList();

List<Map<String, dynamic>> parseQuizQuestions(
  Iterable<Map<String, dynamic>> documents,
) =>
    documents.map((data) {
      final question = data['question'];
      final options = data['options'];
      final correct = data['correctIndex'];
      if (question is! String ||
          question.trim().isEmpty ||
          options is! List ||
          options.length < 2 ||
          options.any((option) => option is! String || option.trim().isEmpty) ||
          correct is! int ||
          correct < 0 ||
          correct >= options.length) {
        throw const FormatException('Invalid quiz question');
      }
      final answers = options.cast<String>().map((s) => s.trim()).toList();
      if (answers.toSet().length != answers.length) {
        throw const FormatException('Duplicate quiz answers');
      }
      return {
        'question': question.trim(),
        'answers': answers,
        'correct': correct,
        'explanation': data['explanation'] is String ? data['explanation'] : '',
      };
    }).toList();
