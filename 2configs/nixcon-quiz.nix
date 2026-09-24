let
  domain = "quiz.lassul.us";
  port = 8773;
in
{ self, ... }:
{
  # nixcon-quiz: live multiplayer quiz for NixCon. Everyone answers the same
  # question against the same server clock; /spectate is the 16:9 screen for
  # the livestream with a QR code to join.
  #
  # The questions are not part of any repository (whoever reads them knows
  # every answer) and stay out of the world-readable store. Copy them over
  # after deploying; until then the service is skipped:
  #   rsync -r --delete ~/src/nixcon-quiz/questions/ root@neoprism.r:/var/lib/nixcon-quiz/questions/
  #   ssh root@neoprism.r systemctl restart nixcon-quiz
  imports = [ self.inputs.nixcon-quiz.nixosModules.default ];

  services.nixcon-quiz = {
    enable = true;
    host = "127.0.0.1";
    inherit port domain;
  };

  # One address may hold a few tabs (players and a spectator screen) and
  # reload at a human pace; each tab keeps one event stream open.
  services.nginx.appendHttpConfig = ''
    limit_conn_zone $binary_remote_addr zone=nixcon_quiz_conns:10m;
    limit_req_zone $binary_remote_addr zone=nixcon_quiz_joins:10m rate=5r/s;
  '';

  services.nginx.virtualHosts.${domain}.locations."/api/events".extraConfig = ''
    limit_conn nixcon_quiz_conns 16;
    limit_req zone=nixcon_quiz_joins burst=30 nodelay;
    limit_conn_status 429;
    limit_req_status 429;
  '';
}
