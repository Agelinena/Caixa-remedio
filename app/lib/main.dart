// App da caixa de remédios inteligente.
// É um lembrete, não um dispositivo médico.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'notifs.dart';
import 'store.dart';
import 'tela_agenda.dart';
import 'tela_ajustes.dart';
import 'tela_conectar.dart';
import 'tela_historico.dart';
import 'tela_hoje.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.I.carregar();
  await Notifs.init();
  runApp(const CaixaApp());
}

class CaixaApp extends StatelessWidget {
  const CaixaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)),
    );
    return MaterialApp(
      title: 'Caixa de remédios',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        // Letras maiores: o app é para quem tem dificuldade de leitura.
        textTheme: base.textTheme.apply(fontSizeFactor: 1.15),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 56),
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Raiz(),
    );
  }
}

class Raiz extends StatelessWidget {
  const Raiz({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Store.I,
      builder: (context, _) => Store.I.pareado ? const Inicio() : const TelaConectar(),
    );
  }
}

class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> with WidgetsBindingObserver {
  int _aba = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Notifs.pedirPermissao();
    Store.I.carregarTudo();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => Store.I.atualizarEstado());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Store.I.carregarTudo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const telas = [TelaHoje(), TelaAgenda(), TelaHistorico(), TelaAjustes()];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _aba, children: telas)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) {
          setState(() => _aba = i);
          if (i == 2) Store.I.carregarEventos();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'Hoje'),
          NavigationDestination(icon: Icon(Icons.medication), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Histórico'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}
