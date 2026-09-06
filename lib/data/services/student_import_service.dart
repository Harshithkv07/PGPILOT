import 'dart:io';

/// One student row read out of a CSV file.
class ImportRow {
  final String name;
  final String roomNumber;
  final int lineNumber;

  ImportRow({required this.name, required this.roomNumber, required this.lineNumber});
}

/// A row that could not be understood, kept so the user can be told why.
class ImportProblem {
  final int lineNumber;
  final String rawLine;
  final String reason;

  ImportProblem({required this.lineNumber, required this.rawLine, required this.reason});
}

class ParsedCsv {
  final List<ImportRow> rows;
  final List<ImportProblem> problems;

  ParsedCsv({required this.rows, required this.problems});
}

/// Reads a CSV of students into name + room code pairs.
///
/// Deliberately forgiving about layout, because hand-made rosters vary:
/// a header row names the columns (so an extra serial-number column is
/// ignored rather than mistaken for the room), and quoted names are handled.
class StudentImportService {
  Future<ParsedCsv> parseFile(String path) async {
    final content = await File(path).readAsString();
    return parseString(content);
  }

  ParsedCsv parseString(String content) {
    final rows = <ImportRow>[];
    final problems = <ImportProblem>[];

    final lines = content.split(RegExp(r'\r\n|\r|\n'));

    // Work out which column holds what. A header row is the reliable signal —
    // guessing by "which cell is a number" is not enough, because rosters
    // often carry a serial-number column that is numeric too.
    int? roomIndex;
    int? nameIndex;
    var firstDataLine = 0;

    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;

      final header = _splitCsvLine(lines[i]).map((c) => c.trim().toLowerCase()).toList();
      for (var c = 0; c < header.length; c++) {
        final h = header[c];
        if (roomIndex == null && (h == 'room' || h.startsWith('room'))) roomIndex = c;
        if (nameIndex == null && (h == 'name' || h.contains('name'))) nameIndex = c;
      }

      if (roomIndex != null && nameIndex != null) {
        firstDataLine = i + 1; // header consumed
      } else {
        // No usable header. Fall back to position, which is only safe when
        // there are exactly two columns: the numeric one is the room.
        roomIndex = null;
        nameIndex = null;
      }
      break;
    }

    for (var i = firstDataLine; i < lines.length; i++) {
      final raw = lines[i];
      final lineNumber = i + 1;

      if (raw.trim().isEmpty) continue;

      final cells = _splitCsvLine(raw).map((c) => c.trim()).toList();
      if (cells.length < 2) {
        problems.add(ImportProblem(
          lineNumber: lineNumber,
          rawLine: raw,
          reason: 'Needs at least a name and a room number',
        ));
        continue;
      }

      String? nameCell;
      String? roomCell;

      final ri = roomIndex;
      final ni = nameIndex;

      if (ri != null && ni != null) {
        if (ri < cells.length) roomCell = cells[ri];
        if (ni < cells.length) nameCell = cells[ni];
      } else if (cells.length == 2) {
        // Two columns, no header: whichever parses as a number is the room.
        if (int.tryParse(cells[0]) != null) {
          roomCell = cells[0];
          nameCell = cells[1];
        } else {
          nameCell = cells[0];
          roomCell = cells[1];
        }
      } else {
        problems.add(ImportProblem(
          lineNumber: lineNumber,
          rawLine: raw,
          reason: 'Could not tell which column is the room — add a header row naming them',
        ));
        continue;
      }

      // Room codes are kept exactly as written, so zero-padded codes like
      // "0002" survive intact rather than collapsing to 2.
      final roomNumber = roomCell?.trim() ?? '';

      if (roomNumber.isEmpty) {
        problems.add(ImportProblem(
          lineNumber: lineNumber,
          rawLine: raw,
          reason: 'No room number found',
        ));
        continue;
      }

      if (nameCell == null || nameCell.isEmpty) {
        problems.add(ImportProblem(
          lineNumber: lineNumber,
          rawLine: raw,
          reason: 'No name found',
        ));
        continue;
      }

      rows.add(ImportRow(name: nameCell, roomNumber: roomNumber, lineNumber: lineNumber));
    }

    return ParsedCsv(rows: rows, problems: problems);
  }

  /// Splits one CSV line, honouring double-quoted cells so that a name
  /// like "Kumar, Raj" stays a single field.
  List<String> _splitCsvLine(String line) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];

      if (ch == '"') {
        // A doubled quote inside a quoted cell is a literal quote.
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        cells.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    cells.add(buffer.toString());

    return cells;
  }
}
