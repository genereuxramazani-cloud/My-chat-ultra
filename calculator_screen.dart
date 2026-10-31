import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';

class CalculatorScreen extends StatefulWidget {
  final String userPhone;
  const CalculatorScreen({super.key, required this.userPhone});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expression = '';
  String _result = '';
  String _error = '';

  final CollectionReference _calculatorDocs =
      FirebaseFirestore.instance.collection('calculatrice');

  @override
  void initState() {
    super.initState();
    _createCalculatorDocument();
  }

  Future<void> _createCalculatorDocument() async {
    await _calculatorDocs.doc(widget.userPhone).set(
      {
        'createdAt': Timestamp.now(),
        'lastExpression': _expression,
        'lastResult': _result,
      },
      SetOptions(merge: true),
    );
  }

  void _appendCharacter(String value) {
    setState(() {
      if (_expression == '0' && value != '.') {
        _expression = value;
      } else {
        _expression += value;
      }
      _error = '';
    });
  }

  void _clearExpression() {
    setState(() {
      _expression = '';
      _result = '';
      _error = '';
    });
  }

  void _deleteCharacter() {
    if (_expression.isEmpty) return;
    setState(() {
      _expression = _expression.substring(0, _expression.length - 1);
      _error = '';
    });
  }

  Future<void> _calculateResult() async {
    if (_expression.isEmpty) return;

    try {
      final value = _evaluateExpression(_expression);
      final formatted = value.toString();
      setState(() {
        _result = formatted;
        _error = '';
      });

      await _calculatorDocs.doc(widget.userPhone).set(
        {
          'lastExpression': _expression,
          'lastResult': formatted,
          'updatedAt': Timestamp.now(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      setState(() {
        _result = '';
        _error = 'Expression invalide';
      });
    }
  }

  double _evaluateExpression(String expression) {
    final tokens =
        _tokenize(expression.replaceAll('×', '*').replaceAll('÷', '/'));
    final rpn = _toRpn(tokens);
    return _evaluateRpn(rpn);
  }

  List<String> _tokenize(String expression) {
    final tokens = <String>[];
    final buffer = StringBuffer();

    for (var i = 0; i < expression.length; i++) {
      final char = expression[i];
      if ('0123456789.'.contains(char)) {
        buffer.write(char);
      } else {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        if ('+-*/%()'.contains(char)) {
          final isNegativeSign = char == '-' &&
              (tokens.isEmpty ||
                  tokens.last == '(' ||
                  '+-*/%'.contains(tokens.last));
          if (isNegativeSign) {
            buffer.write(char);
          } else {
            tokens.add(char);
          }
        }
      }
    }
    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }
    return tokens;
  }

  int _precedence(String op) {
    if (op == '+' || op == '-') return 1;
    if (op == '*' || op == '/' || op == '%') return 2;
    return 0;
  }

  List<String> _toRpn(List<String> tokens) {
    final output = <String>[];
    final operators = <String>[];

    for (final token in tokens) {
      if (double.tryParse(token) != null) {
        output.add(token);
      } else if ('+-*/%'.contains(token)) {
        while (operators.isNotEmpty &&
            operators.last != '(' &&
            _precedence(operators.last) >= _precedence(token)) {
          output.add(operators.removeLast());
        }
        operators.add(token);
      } else if (token == '(') {
        operators.add(token);
      } else if (token == ')') {
        while (operators.isNotEmpty && operators.last != '(') {
          output.add(operators.removeLast());
        }
        if (operators.isNotEmpty && operators.last == '(') {
          operators.removeLast();
        }
      }
    }

    while (operators.isNotEmpty) {
      output.add(operators.removeLast());
    }

    return output;
  }

  double _evaluateRpn(List<String> tokens) {
    final stack = <double>[];

    for (final token in tokens) {
      final value = double.tryParse(token);
      if (value != null) {
        stack.add(value);
      } else {
        if (stack.length < 2) throw FormatException('Expression invalide');
        final right = stack.removeLast();
        final left = stack.removeLast();
        switch (token) {
          case '+':
            stack.add(left + right);
            break;
          case '-':
            stack.add(left - right);
            break;
          case '*':
            stack.add(left * right);
            break;
          case '/':
            if (right == 0) throw FormatException('Division par zéro');
            stack.add(left / right);
            break;
          case '%':
            stack.add(left % right);
            break;
          default:
            throw FormatException('Opérateur inconnu');
        }
      }
    }

    if (stack.length != 1) throw FormatException('Expression invalide');
    return stack.first;
  }

  Widget _buildButton(String label,
      {Color? color, Color textColor = Colors.white}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? const Color(0xFF222233),
            padding: const EdgeInsets.symmetric(vertical: 22),
          ),
          onPressed: () {
            if (label == 'C') {
              _clearExpression();
            } else if (label == 'DEL') {
              _deleteCharacter();
            } else if (label == '=') {
              _calculateResult();
            } else {
              _appendCharacter(label == '×' || label == '÷' ? label : label);
            }
          },
          child: Text(label,
              style: TextStyle(
                  color: textColor, fontSize: 20, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF050510),
        title: const Text('Calculatrice',
            style: TextStyle(color: kGold, letterSpacing: 1.5)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: kGradientBg),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF10101D),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kGold.withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      reverse: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('$_expression',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                              )),
                          const SizedBox(height: 12),
                          Text(_result.isEmpty ? '0' : _result,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: kGold,
                                fontSize: 38,
                                fontWeight: FontWeight.bold,
                              )),
                        ],
                      ),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_error,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 14)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              flex: 2,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(children: [
                      _buildButton('C', color: kGold, textColor: Colors.black),
                      _buildButton('DEL',
                          color: kGold, textColor: Colors.black),
                      _buildButton('%', color: const Color(0xFF2A2A3F)),
                      _buildButton('÷', color: const Color(0xFF2A2A3F)),
                    ]),
                    Row(children: [
                      _buildButton('7'),
                      _buildButton('8'),
                      _buildButton('9'),
                      _buildButton('×', color: const Color(0xFF2A2A3F)),
                    ]),
                    Row(children: [
                      _buildButton('4'),
                      _buildButton('5'),
                      _buildButton('6'),
                      _buildButton('-', color: const Color(0xFF2A2A3F)),
                    ]),
                    Row(children: [
                      _buildButton('1'),
                      _buildButton('2'),
                      _buildButton('3'),
                      _buildButton('+', color: const Color(0xFF2A2A3F)),
                    ]),
                    Row(children: [
                      _buildButton('0'),
                      _buildButton('.'),
                      _buildButton('=', color: kGold, textColor: Colors.black),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
