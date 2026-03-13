import 'package:flutter/material.dart';
import 'gasto.dart';
import 'receita.dart';

const Map<String, String> dicasPorCategoria = {
  'Alimentação':
      'Tente cozinhar mais em casa. Pode economizar até 40% comparado a comer fora.',
  'Mercado':
      'Faça listas de compras antes de ir ao mercado e evite compras por impulso.',
  'Transporte':
      'Considere caronas compartilhadas ou transporte público para reduzir custos.',
  'Lazer':
      'Busque opções gratuitas de lazer como parques, eventos culturais e afins.',
  'Saúde':
      'Mantenha hábitos preventivos para evitar gastos maiores no futuro.',
  'Moradia':
      'Revise contratos de serviços como internet e energia para encontrar planos melhores.',
  'Educação': 'Explore cursos gratuitos online como complemento aos pagos.',
  'Assinaturas':
      'Revise suas assinaturas ativas. Cancele as que não usa — pequenos valores mensais somam muito ao longo do ano.',
  'Vestuário':
      'Prefira comprar roupas fora de temporada ou em promoções. Evite compras por impulso.',
  'Cuidados Pessoais':
      'Compare preços de produtos de higiene e beleza. Versões genéricas costumam ter a mesma qualidade.',
  'Presentes':
      'Planeje presentes com antecedência para evitar gastos de última hora e aproveitar promoções.',
  'Outros': 'Revise esses gastos — muitos podem ser evitados ou reduzidos.',
};

class RegraFinanceira {
  final IconData icone;
  final Color cor;
  final String titulo;
  final String mensagem;
  final bool destaque;

  const RegraFinanceira({
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.mensagem,
    required this.destaque,
  });
}

String _fmt(double v) {
  final parts = v.toStringAsFixed(2).split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
  return 'R\$ $intPart,${parts[1]}';
}

/// Regras financeiras complementares (sem duplicar os cards de Destaques/Alertas).
/// Regras removidas por já existirem na tela: categoria dominante, gastos fixos,
/// comparação de período, gastos evitáveis e gastos inesperados.
List<RegraFinanceira> calcularRegras({
  required List<Gasto> gastos,
  required List<Receita> receitas,
  List<Gasto> gastosAnteriores = const [],
}) {
  final regras = <RegraFinanceira>[];
  final totalGastos = gastos.fold(0.0, (s, g) => s + g.valor);
  final totalReceitas = receitas.fold(0.0, (s, r) => s + r.valor);

  // ── Sem receita registrada ────────────────────────────────────────────────
  if (receitas.isEmpty) {
    regras.add(const RegraFinanceira(
      icone: Icons.account_balance_wallet,
      cor: Colors.blueGrey,
      titulo: 'Sem receitas registradas',
      mensagem:
          'Nenhuma receita cadastrada neste período. Registre suas entradas '
          'para acompanhar seu saldo real.',
      destaque: false,
    ));
  }

  // ── Saldo negativo ou economia saudável ───────────────────────────────────
  if (totalReceitas > 0) {
    if (totalGastos > totalReceitas) {
      final deficit = totalGastos - totalReceitas;
      regras.add(RegraFinanceira(
        icone: Icons.money_off,
        cor: Colors.red,
        titulo: 'Saldo negativo',
        mensagem:
            'Você gastou ${_fmt(deficit)} a mais do que recebeu. '
            'Atenção ao endividamento.',
        destaque: true,
      ));
    } else {
      final economia = totalReceitas - totalGastos;
      final pct = economia / totalReceitas * 100;
      if (pct >= 20) {
        regras.add(RegraFinanceira(
          icone: Icons.savings,
          cor: Colors.green,
          titulo: 'Boa taxa de economia',
          mensagem:
              'Você economizou ${pct.toStringAsFixed(1)}% da sua renda '
              '(${_fmt(economia)}). Continue assim!',
          destaque: false,
        ));
      }
    }
  }

  // ── Alimentação/Mercado >35% do total ────────────────────────────────────
  if (totalGastos > 0) {
    final alim = gastos
        .where((g) => g.categoria == 'Alimentação' || g.categoria == 'Mercado')
        .fold(0.0, (s, g) => s + g.valor);
    final pct = alim / totalGastos * 100;
    if (pct >= 35) {
      regras.add(RegraFinanceira(
        icone: Icons.restaurant,
        cor: Colors.orange,
        titulo: 'Alimentação elevada',
        mensagem:
            'Alimentação/Mercado representa ${pct.toStringAsFixed(1)}% do total '
            '(${_fmt(alim)}). Cozinhar em casa pode reduzir até 40%.',
        destaque: true,
      ));
    }
  }

  // ── Lazer + Assinaturas >20% do total ────────────────────────────────────
  if (totalGastos > 0) {
    final lazer = gastos
        .where((g) => g.categoria == 'Lazer' || g.categoria == 'Assinaturas')
        .fold(0.0, (s, g) => s + g.valor);
    final pct = lazer / totalGastos * 100;
    if (pct >= 20) {
      regras.add(RegraFinanceira(
        icone: Icons.movie,
        cor: Colors.purple,
        titulo: 'Lazer e assinaturas altos',
        mensagem:
            'Lazer e assinaturas somam ${pct.toStringAsFixed(1)}% dos gastos '
            '(${_fmt(lazer)}). Revise assinaturas que não usa.',
        destaque: pct >= 30,
      ));
    }
  }

  // ── Categoria com maior crescimento vs anterior (>50%) ───────────────────
  if (gastosAnteriores.isNotEmpty) {
    final mapaAtual = <String, double>{};
    final mapaAnterior = <String, double>{};
    for (final g in gastos) {
      mapaAtual[g.categoria] = (mapaAtual[g.categoria] ?? 0) + g.valor;
    }
    for (final g in gastosAnteriores) {
      mapaAnterior[g.categoria] = (mapaAnterior[g.categoria] ?? 0) + g.valor;
    }
    String? catMaisCresceu;
    double maiorCrescimento = 50.0;
    for (final e in mapaAtual.entries) {
      final ant = mapaAnterior[e.key] ?? 0;
      if (ant > 0) {
        final variacao = (e.value - ant) / ant * 100;
        if (variacao > maiorCrescimento) {
          maiorCrescimento = variacao;
          catMaisCresceu = e.key;
        }
      }
    }
    if (catMaisCresceu != null) {
      regras.add(RegraFinanceira(
        icone: Icons.show_chart,
        cor: Colors.amber[800]!,
        titulo: 'Categoria em alta',
        mensagem:
            '$catMaisCresceu cresceu ${maiorCrescimento.toStringAsFixed(1)}% '
            'em relação ao período anterior. Fique de olho.',
        destaque: true,
      ));
    }
  }

  // ── Dica personalizada para a categoria mais gasta ───────────────────────
  if (gastos.isNotEmpty && totalGastos > 0) {
    final mapa = <String, double>{};
    for (final g in gastos) {
      mapa[g.categoria] = (mapa[g.categoria] ?? 0) + g.valor;
    }
    final top = mapa.entries.reduce((a, b) => a.value > b.value ? a : b);
    final dica = dicasPorCategoria[top.key] ??
        'Continue monitorando seus gastos para identificar oportunidades de economia.';
    regras.add(RegraFinanceira(
      icone: Icons.lightbulb,
      cor: Colors.blue,
      titulo: 'Dica — ${top.key}',
      mensagem: dica,
      destaque: false,
    ));
  }

  return regras;
}
