import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'gasto.dart';
import 'main.dart';
import 'atualizar_parcelas_result.dart';
import 'fade_route.dart';
import 'multiplos_gastos_screen.dart';

class MeusGastosScreen extends StatefulWidget {
  const MeusGastosScreen({super.key});

  @override
  State<MeusGastosScreen> createState() => _MeusGastosScreenState();
}

class _MeusGastosScreenState extends State<MeusGastosScreen> {
  late Box<Gasto> _gastosBox;
  bool _filtroNaoDetalhado = false;

  @override
  void initState() {
    super.initState();
    _gastosBox = Hive.box<Gasto>('gastos');
  }

  String _formatarValor(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  String _formatarData(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  List<Map<String, dynamic>> get _itens {
    final agora = DateTime.now();
    final limite = DateTime(agora.year, agora.month, agora.day)
        .subtract(const Duration(days: 2));
    final lista = <Map<String, dynamic>>[];
    for (int i = 0; i < _gastosBox.length; i++) {
      final g = _gastosBox.getAt(i);
      if (g == null) continue;
      final dataGasto = DateTime(g.data.year, g.data.month, g.data.day);
      if (dataGasto.isBefore(limite)) continue;
      if (_filtroNaoDetalhado && g.detalhado) continue;
      lista.add({'item': g, 'index': i});
    }
    lista.sort((a, b) =>
        (b['item'] as Gasto).data.compareTo((a['item'] as Gasto).data));
    return lista;
  }

  Future<void> _editarGasto(Map<String, dynamic> item) async {
    final boxIndex = item['index'] as int;
    final resultado = await Navigator.push<dynamic>(
      context,
      FadeRoute(page: AdicionarGastoScreen(gasto: item['item'] as Gasto)),
    );
    if (resultado == null) return;
    if (resultado is Gasto) {
      await _gastosBox.putAt(boxIndex, resultado);
    } else if (resultado is AtualizarParcelasResult) {
      await _gastosBox.putAt(boxIndex, resultado.gastoAtual);
      for (final entry in resultado.proximas) {
        await _gastosBox.putAt(entry.key, entry.value);
      }
    } else if (resultado is List<Gasto>) {
      for (final parcela in resultado) {
        await _gastosBox.add(parcela);
      }
    }
    setState(() {});
  }

  Future<bool> _confirmarExclusao(Gasto g) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Excluir gasto'),
            content: Text(
                'Deseja excluir "${g.descricao.isNotEmpty ? g.descricao : g.categoria}" de R\$ ${_formatarValor(g.valor)}?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final itens = _itens;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text('Meus Gastos'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey[100],
            child: Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      setState(() => _filtroNaoDetalhado = !_filtroNaoDetalhado),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _filtroNaoDetalhado ? Colors.orange : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _filtroNaoDetalhado
                            ? Colors.orange
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pending_actions,
                            size: 14,
                            color: _filtroNaoDetalhado
                                ? Colors.white
                                : Colors.grey[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Não Detalhados',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _filtroNaoDetalhado
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${itens.length} registro(s) • últimos 3 dias',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Expanded(
            child: itens.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _filtroNaoDetalhado
                              ? 'Nenhum gasto não detalhado nos últimos 3 dias.'
                              : 'Nenhum gasto nos últimos 3 dias.',
                          style: const TextStyle(color: Colors.grey, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: itens.length,
                    itemBuilder: (context, index) {
                      final item = itens[index];
                      final g = item['item'] as Gasto;
                      final naoDetalhado = !g.detalhado;
                      return Dismissible(
                        key: Key('meugasto_${g.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) => _confirmarExclusao(g),
                        onDismissed: (_) async {
                          await _gastosBox.deleteAt(item['index'] as int);
                          setState(() {});
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: naoDetalhado ? Colors.orange : Colors.red,
                                width: 4,
                              ),
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: naoDetalhado
                                  ? Colors.orange[50]
                                  : Colors.red[50],
                              child: Icon(
                                naoDetalhado
                                    ? Icons.pending_actions
                                    : Icons.receipt_long,
                                color:
                                    naoDetalhado ? Colors.orange : Colors.red,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    g.descricao.isNotEmpty
                                        ? g.descricao
                                        : g.categoria,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (naoDetalhado)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[100],
                                      borderRadius: BorderRadius.circular(6),
                                      border:
                                          Border.all(color: Colors.orange),
                                    ),
                                    child: const Text(
                                      'Não Detalhado',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              g.categoria.isNotEmpty && g.categoria != 'Outros'
                                  ? '${_formatarData(g.data)} • ${g.categoria}'
                                  : _formatarData(g.data),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '- R\$ ${_formatarValor(g.valor)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.red,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _editarGasto(item),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // ── Botões inferiores ──
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final resultado = await Navigator.push<dynamic>(
                        context,
                        FadeRoute(page: const AdicionarGastoScreen()),
                      );
                      if (resultado == null) return;
                      if (resultado is List<Gasto>) {
                        for (final p in resultado) {
                          await _gastosBox.add(p);
                        }
                      } else if (resultado is Gasto) {
                        await _gastosBox.add(resultado);
                      } else if (resultado is AtualizarParcelasResult) {
                        await _gastosBox.add(resultado.gastoAtual);
                      }
                      setState(() {});
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Novo Gasto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final salvo = await Navigator.push<bool>(
                        context,
                        FadeRoute(page: const MultiplosGastosScreen()),
                      );
                      if (salvo == true) setState(() {});
                    },
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Múltiplos Gastos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
