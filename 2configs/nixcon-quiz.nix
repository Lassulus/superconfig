let
  domain = "quiz.nixcon.org";
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
  # Break slides for /spectate (PDF/PNG/JPEG/WebP, not in any repository
  # either) are picked up without a restart:
  #   rsync -r --delete ~/src/nixcon-quiz/slides/ root@neoprism.r:/var/lib/nixcon-quiz/slides/
  imports = [ self.inputs.nixcon-quiz.nixosModules.default ];

  services.nixcon-quiz = {
    enable = true;
    host = "127.0.0.1";
    inherit port domain;
    questionSeconds = 30;
  };

  # No per-address limits on the event streams: the venue Wi-Fi puts every
  # phone at NixCon behind one public address, so a per-IP cap cuts off
  # everyone past the first few players. The quiz caps players itself.

  # The quiz's first home; old links and QR codes land on the new name.
  services.nginx.virtualHosts."quiz.lassul.us" = {
    enableACME = true;
    forceSSL = true;
    globalRedirect = domain;
  };
}
