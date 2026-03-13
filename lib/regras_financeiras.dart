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

/// Calcula até 10 regras financeiras dinâmicas baseadas em categorias,
/// comparando gastos e receitas do período atual com o anterior.
List<RegraFinanceira> calcularRegras({
  required List<Gasto> gastos,
  required List<Receita> receitas,
  List<Gasto> gastosAnteriores = const [],
}) {
  final regras = <RegraFinanceira>[];
  final totalGastos = gastos.fold(0.0, (s, g) => s + g.valor);
  final totalReceitas = receitas.fold(0.0, (s, r) => s + r.valor);
  final totalAnterior = gastosAnteriores.fold(0.0, (s, g) => s + g.valor);

  // ── Regra 1: Categoria dominante (≥40% do total) ─────────────────────────
  if (gastos.isNotEmpty && totalGastos > 0) {
    final mapa = <String, double>{};
    for (final g in gastos) {
      mapa[g.categoria] = (mapa[g.categoria] ?? 0) + g.valor;
    }
    final top = mapa.entries.reduce((a, b) => a.value > b.value ? a : b);
    final pct = top.value / totalGastos * 100;
    if (pct >= 40) {
      regras.add(RegraFinanceira(
        icone: Icons.pie_chart,
        cor: Colors.orange,
        titulo: 'Categoria dominante',
        mensagem:
            '${top.key} representa ${pct.toStringAsFixed(1)}% dos seus gastos '
            '(${_fmt(top.value)}). Considere diversificar.',
        destaque: true,
      ));
    }
  }

  // ── Regra 2: Gastos fixos comprometem >70% da renda ──────────────────────
  if (totalReceitas > 0) {
    final fixos =
        gastos.where((g) => g.tipoGasto == 'Fixo').fold(0.0, (s, g) => s + g.valor);
    final pct = fixos / totalReceitas * 100;
    if (pct >= 70) {
      regras.add(RegraFinanceira(
        icone: Icons.lock_clock,
        cor: Colors.red,
        titulo: 'Gastos fixos elevados',
        mensagem:
            '${pct.toStringAsFixed(1)}% da sua renda está comprometida com '
            'gastos fixos (${_fmt(fixos)}). Pouco espaço para imprevistos.',
        destaque: true,
      ));
    }
  }

  // ── Regra 3: Gastos cresceram >20% vs período anterior ───────────────────
  if (gastosAnteriores.isNotEmpty && totalAnterior > 0) {
    final variacao = (totalGastos - totalAnterior) / totalAnterior * 100;
    if (variacao > 20) {
      regras.add(RegraFinanceira(
        icone: Icons.trending_up,
        cor: Colors.red,
        titulo: 'Gastos em alta',
        mensagem:
            'Seus gastos cresceram ${variacao.toStringAsFixed(1)}% em relação '
            'ao período anterior (${_fmt(totalAnterior)} → ${_fmt(totalGastos)}).',
        destaque: true,
      ));
    } else if (variacao < -10) {
      regras.add(RegraFinanceira(
        icone: Icons.trending_down,
        cor: Colors.green,
        titulo: 'Gastos em queda',
        mensagem:
            'Parabéns! Seus gastos caíram ${variacao.abs().toStringAsFixed(1)}% '
            'em relação ao período anterior.',
        destaque: false,
      ));
    }
  }

  // ── Regra 4: Gastos evitáveis ─────────────────────────────────────────────
  if (totalGastos > 0) {
    final evitaveis =
        gastos.where((g) => g.gastoEvitavel).fold(0.0, (s, g) => s + g.valor);
    if (evitaveis > 0) {
      final pct = evitaveis / totalGastos * 100;
      regras.add(RegraFinanceira(
        icone: Icons.block,
        cor: Colors.deepOrange,
        titulo: 'Gastos evitáveis detectados',
        mensagem:
            '${_fmt(evitaveis)} (${pct.toStringAsFixed(1)}% do total) '
            'poderiam ter sido evitados. Revise esses hábitos.',
        destaque: pct >= 10,
      ));
    }
  }

  // ── Regra 5: Sem receita registrada ──────────────────────────────────────
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

  // ── Regra 6: Saldo negativo ou economia saudável ──────────────────────────
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

  // ── Regra 7: Gastos inesperados altos (>15%) ──────────────────────────────
  if (totalGastos > 0) {
    final inesperados =
        gastos.where((g) => !g.gastoEsperado).fold(0.0, (s, g) => s + g.valor);
    final pct = inesperados / totalGastos * 100;
    if (pct >= 15) {
      regras.add(RegraFinanceira(
        icone: Icons.error_outline,
        cor: Colors.orange,
        titulo: 'Muitos gastos inesperados',
        mensagem:
            '${pct.toStringAsFixed(1)}% dos seus gastos (${_fmt(inesperados)}) '
            'não estavam previstos. Considere criar uma reserva de emergência.',
        destaque: true,
      ));
    }
  }

  // ── Regra 8: Alimentação/Mercado >35% do total ───────────────────────────
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

  // ── Regra 9: Lazer + Assinaturas >20% do total ───────────────────────────
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

  // ── Regra 10: Categoria com maior crescimento vs anterior (>50%) ──────────
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

  // ── Regra Dica: dica personalizada para a categoria mais gasta ───────────
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
