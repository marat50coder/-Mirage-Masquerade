import 'dart:convert';

import '../config/house_brief.dart';
import '../core/house_models.dart';
import 'wardrobe.dart';
import 'footlight_agent.dart';
import 'playbill_scout.dart';

/// Posts the attribution payload to the config endpoint and parses the reply.
class BoxOffice {
  BoxOffice(this._agent, this._vault);

  final FootlightAgent _agent;
  final Wardrobe _vault;

  static const Duration _timeout = Duration(seconds: 17);

  Future<HouseReply> request(Map<String, dynamic> payload) async {
    if (!HouseBrief.houseCredentialsReady) {
      return HouseReply.rejected('credentials_unavailable');
    }
    try {
      houseTrace(() => '[MM.BOX] request ${jsonEncode(payload)}');
      final response = await _agent
          .post(
            Uri.parse(HouseBrief.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
      houseTrace(
        () => '[MM.BOX] response ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        // The server WAS reached (e.g. 404 "no data" = organic verdict), so
        // this counts as a real answer — the caller may commit the white game.
        return HouseReply.rejected(
          'http_${response.statusCode}',
          serverResponded: true,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return HouseReply.rejected('invalid_response');
      final reply = HouseReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination) {
        await _vault.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      houseTrace(() => '[MM.BOX] failed: $error');
      return HouseReply.rejected('network_failure');
    }
  }
}
