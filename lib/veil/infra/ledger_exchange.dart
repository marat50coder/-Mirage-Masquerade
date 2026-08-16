import 'dart:convert';

import '../config/veil_config.dart';
import '../core/veil_models.dart';
import 'masque_vault.dart';
import 'mummer_agent.dart';
import 'trace_courier.dart';

/// Posts the attribution payload to the config endpoint and parses the reply.
class LedgerExchange {
  LedgerExchange(this._agent, this._vault);

  final MummerAgent _agent;
  final MasqueVault _vault;

  static const Duration _timeout = Duration(seconds: 19);

  Future<VeilReply> request(Map<String, dynamic> payload) async {
    if (!VeilConfig.veilCredentialsReady) {
      return VeilReply.rejected('credentials_unavailable');
    }
    try {
      veilTrace(() => '[MSQ.LEDGER] request ${jsonEncode(payload)}');
      final response = await _agent
          .post(
            Uri.parse(VeilConfig.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
      veilTrace(
        () => '[MSQ.LEDGER] response ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        // The server WAS reached (e.g. 404 "no data" = organic verdict), so
        // this counts as a real answer — the caller may commit the white game.
        return VeilReply.rejected(
          'http_${response.statusCode}',
          serverResponded: true,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return VeilReply.rejected('invalid_response');
      final reply = VeilReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination) {
        await _vault.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      veilTrace(() => '[MSQ.LEDGER] failed: $error');
      return VeilReply.rejected('network_failure');
    }
  }
}
