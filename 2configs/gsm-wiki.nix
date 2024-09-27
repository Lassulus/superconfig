{ pkgs, ... }:
{
  services.nginx.virtualHosts."docs.c3gsm.de" = {
    forceSSL = true;
    enableACME = true;
    locations."/".extraConfig = ''
      auth_basic "Restricted Content";
      auth_basic_user_file ${pkgs.writeText "c3gsm-user-pass" ''
        c3gsm:$apr1$q9OrPI4C$7AY4EIp3J2Xc4eLMbPGE21
      ''};
      root /srv/http/docs.c3gsm.de;
    '';
  };

  services.nginx.virtualHosts."c3gsm.de" = {
    forceSSL = true;
    enableACME = true;
    root = "/srv/http/c3gsm.de/wwwroot";
    locations."/" = {
      tryFiles = "$uri $uri/ $uri.html =404";
    };
  };

  systemd.services."c3gsm-website-cleanup-preview" = {
    script = ''
      set -eu
      ${pkgs.findutils}/bin/find \
        /srv/http/c3gsm.de/wwwroot/pre \
        -mindepth 1 \
        -ctime +7 \
        -delete
    '';
    startAt = "daily";
    serviceConfig = {
      Type = "oneshot";
      User = "c3gsm";
    };
  };

  users.users.c3gsm-docs = {
    isNormalUser = true;
    home = "/srv/http/docs.c3gsm.de";
    createHome = true;
    homeMode = "750";
    useDefaultShell = true;
    group = "nginx";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAlW1fvCrVXhVH/z76fXBWYR/qyecYTE9VOOkFLJ6OwG user@osmocom-dev"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBV1+1YcOyLA16i9tPDMZsdMKNfVkh884QQGQkHy7L7t gitlab-deployment"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDrhZNSJ7Yqr+DuwQLSRdZXcEPs0cnH87T+6tg4dbzZSVuxEWuGPeo1SR7XU0l7Ut4n/HhBLu1Lw+BeIsH2FbbeLP5QnYEWaCDpaQxy8SYb+6tn7x6GxG0at4hrdk3vm+UAltqhBQLvpZGfLEvGr+E1e0GfQq0y2MU6glqzmOP43h8XcJ7htTGkduuO947K7WTcv5QaN7Mc1uR+a1EvJ2N+t09x1Hl0sm6MwJvPv88AzrmmOWfikJre7XQspmb5XpecNzSAPZ187MQj8XTqzky4RQFo76/yzn++5XCdjJNGOiJb+W5ob+CXJqdwdBZGyo7n4ZNMfqNV3H1Me3XMunjwwnKczO6nN9iQzTQyjqeMsz4p51iz1ccjXvnKgo5NTff+FwU643LYNH3y9WdzqgLkoGR5R7Dy05qSOOQ2dGPGZi18h2iYTz5/OjjJsU+0bIaY0YGkIbVRhFDvToHew09VLSd7nWOqGIrnINwNsPYc7THOn0ys+RTcMPlxE92lIHaKBUl/+a+q5IGzwMEJfY9kuo2GtEiwfe1gWo7nX4O0hE/B1aqbQ9umrVo/CTNvqOHI+tr/LwQYoyWRFlKEZNqFtOdyw6lf+g4CvmupIct9IEYWMLi7L03i6vhnBUf8aQuguC3FCOC3lBdo2hecw29i8j0F87a1rsVRFm2CDHsOQQ== openpgp:0xB565044B"
    ];
  };

  users.users.c3gsm = {
    isNormalUser = true;
    home = "/srv/http/c3gsm.de";
    createHome = true;
    homeMode = "750";
    useDefaultShell = true;
    group = "nginx";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAlW1fvCrVXhVH/z76fXBWYR/qyecYTE9VOOkFLJ6OwG user@osmocom-dev"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBV1+1YcOyLA16i9tPDMZsdMKNfVkh884QQGQkHy7L7t gitlab-deployment"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDrhZNSJ7Yqr+DuwQLSRdZXcEPs0cnH87T+6tg4dbzZSVuxEWuGPeo1SR7XU0l7Ut4n/HhBLu1Lw+BeIsH2FbbeLP5QnYEWaCDpaQxy8SYb+6tn7x6GxG0at4hrdk3vm+UAltqhBQLvpZGfLEvGr+E1e0GfQq0y2MU6glqzmOP43h8XcJ7htTGkduuO947K7WTcv5QaN7Mc1uR+a1EvJ2N+t09x1Hl0sm6MwJvPv88AzrmmOWfikJre7XQspmb5XpecNzSAPZ187MQj8XTqzky4RQFo76/yzn++5XCdjJNGOiJb+W5ob+CXJqdwdBZGyo7n4ZNMfqNV3H1Me3XMunjwwnKczO6nN9iQzTQyjqeMsz4p51iz1ccjXvnKgo5NTff+FwU643LYNH3y9WdzqgLkoGR5R7Dy05qSOOQ2dGPGZi18h2iYTz5/OjjJsU+0bIaY0YGkIbVRhFDvToHew09VLSd7nWOqGIrnINwNsPYc7THOn0ys+RTcMPlxE92lIHaKBUl/+a+q5IGzwMEJfY9kuo2GtEiwfe1gWo7nX4O0hE/B1aqbQ9umrVo/CTNvqOHI+tr/LwQYoyWRFlKEZNqFtOdyw6lf+g4CvmupIct9IEYWMLi7L03i6vhnBUf8aQuguC3FCOC3lBdo2hecw29i8j0F87a1rsVRFm2CDHsOQQ== openpgp:0xB565044B"
    ];
  };
}
