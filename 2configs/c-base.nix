{ config, lib, pkgs, ... }:

{

  environment.systemPackages = [
    pkgs.cifs-utils
  ];


  clanCore.facts.services.c-base = {
    secret."c-base.txt" = { };
    generator.prompt = ''
      Please enter your username in the first line and your c-base password in the next line
    '';
    generator.script = ''
      echo "$prompt_value" > "$secrets"/c-base.txt
    '';
  };

  systemd.network.networks.c-base = {
    matchConfig.Name = "c-base";
    networkConfig = {
      IgnoreCarrierLoss = "3s";
      KeepConfiguration = "static";
      DNS = "10.0.1.254";
      Domains = "cbrp3.c-base.org";
    };
    routes = [
      { routeConfig = {
        Destination = "10.0.0.0/23";
        Gateway = "172.31.77.1";
      };}
      { routeConfig = {
        Destination = "91.102.9.99/32"; # vorstand.c-base.org
        Gateway = "172.31.77.1";
      };}
    ];
  };
  services.openvpn.servers.c-base = {
    config = ''
      remote vpn.ext.c-base.org 1194
      verify-x509-name vpn.ext.c-base.org name
      client
      proto udp
      dev-type tun
      dev c-base
      resolv-retry infinite
      nobind
      # user openvpn
      # group openvpn
      persist-key
      persist-tun
      comp-lzo
      # register-dns
      # block-outside-dns
      script-security 2
      auth-user-pass ${config.clanCore.facts.services.c-base.secret."c-base.txt".path}
      #auth-user-pass
      key-direction 1
      <tls-auth>
      #
      # 2048 bit OpenVPN static key
      #
      -----BEGIN OpenVPN Static key V1-----
      54a66ed1048bed7508703347e89d68d6
      5586e6a5d1218cf8675941031d540be6
      993e07200a16ad3b770b659932ee71e5
      f8080b5c9fa2acb3893abd40fad2552c
      fdaf17565e617ae450efcccf5652dca5
      a16419509024b075941098731eb25ac0
      a64f963ece3dca1d2a64a9c5e17839d7
      5b5080165a9b2dc90ef111879d7d3173
      2d1027ae42d869394aca08da4472a9d0
      6b724b4ed43a957feef7d6dfc86da241
      74828fa0e1240941586f0d937cac32fc
      13cc81e7bed58817353d6afaff7e6a26
      4f9cc086af79c1cdca660d86e18cff96
      69dd3d392caf09a468894a8504f4cc7c
      7ae0072e6d9ad90b166ad13a39c57b3c
      3a869e27a1d89deb161c255227551713
      -----END OpenVPN Static key V1-----
      </tls-auth>
      <ca>
      -----BEGIN CERTIFICATE-----
      MIIGsDCCBJigAwIBAgIJAPkM1l2zA306MA0GCSqGSIb3DQEBCwUAMIGWMQswCQYD
      VQQGEwJERTEPMA0GA1UEBxMGQmVybGluMRswGQYDVQQLExJ2cG4uZXh0LmMtYmFz
      ZS5vcmcxGzAZBgNVBAMTEnZwbi5leHQuYy1iYXNlLm9yZzEbMBkGA1UEKRMSdnBu
      LmV4dC5jLWJhc2Uub3JnMR8wHQYJKoZIhvcNAQkBFhBhZG1heEBjLWJhc2Uub3Jn
      MB4XDTE2MDcwOTE4MjkyMFoXDTI2MDcxMDE4MjkyMFowgZYxCzAJBgNVBAYTAkRF
      MQ8wDQYDVQQHEwZCZXJsaW4xGzAZBgNVBAsTEnZwbi5leHQuYy1iYXNlLm9yZzEb
      MBkGA1UEAxMSdnBuLmV4dC5jLWJhc2Uub3JnMRswGQYDVQQpExJ2cG4uZXh0LmMt
      YmFzZS5vcmcxHzAdBgkqhkiG9w0BCQEWEGFkbWF4QGMtYmFzZS5vcmcwggIiMA0G
      CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDXEs+uWCXLNmm+lgP9x7u3FqWa4pPI
      h64c6EWIULMATrhEw+Ej4fpCXwU9otFaO04fAeJmZGkDcnAYdBDiCeI0luOSdj44
      Bg9KecSei/TskqjhDVnEBp65hiz0rZE6c1baPdLYmD5xrXWb3i0zrlBYFawuL6C2
      lwVCEm3cadvkDJ2DleMuu3NblV8ViIDN0HZqzJNP72g1I0MgohkpetACXlf7MzQV
      PFHfzvb04Rj2lJ8BDhceQ0WmjtVV/Ag6nka5oi954OeHMujRuH+rZYiQZDZpJLHK
      Kh1KWTVlWPRy+AvCi9lweDWSmLccq7Ug4xMtDF4I5qW3tjCd0xqpZ21Xmo2JyKtY
      4h8wEDPqiJvgwvkXsH17GLn5ZxiMcQuRJQYZqJephkzR9uccJeWSS76kwm/vLqG3
      +eORlYnyjiNXtiMIhmAEFjpWUrGH8v4CijpUNP6E63ynGrRVXK684YQXkqL+xPAt
      t6dsMBUwf94a2S1o2kgvuRCim1wlHvf1QsHrO/Hwgpzc8no/daWL+Z9Rq9okTHNK
      nc1G5dv8TkmxIDYnLm07QMzzBoOT36BcGtkEBA+0xhQlX5PyQdM5/jnZVhdSBmoP
      MbZXPoU/gJAIuuBuwdTlgCzYf44/9/YU/AnW8eLrbhm9KtMtoMpatrWorKqk/GPv
      /lGNRQuNffrbiQIDAQABo4H+MIH7MB0GA1UdDgQWBBTf5cYbK+KCF9u9aobFlLbu
      ilwX4jCBywYDVR0jBIHDMIHAgBTf5cYbK+KCF9u9aobFlLbuilwX4qGBnKSBmTCB
      ljELMAkGA1UEBhMCREUxDzANBgNVBAcTBkJlcmxpbjEbMBkGA1UECxMSdnBuLmV4
      dC5jLWJhc2Uub3JnMRswGQYDVQQDExJ2cG4uZXh0LmMtYmFzZS5vcmcxGzAZBgNV
      BCkTEnZwbi5leHQuYy1iYXNlLm9yZzEfMB0GCSqGSIb3DQEJARYQYWRtYXhAYy1i
      YXNlLm9yZ4IJAPkM1l2zA306MAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQELBQAD
      ggIBAMs1moiS7UZ4neOivQjqwKrBbm1j3tgmPLhDfNMmXYarGhnBGAlLxLAQWtG+
      Fnbx8KcsJnrsWcGfZcst1z45S4a5oBdVNKOfgkMOG0glZorIDO8Odrb51rpyzU0v
      0wcNumMNWhkFuo2OTBHPnnJIWEAFwwCCSCL0I0hQxxoaV36kphjuIwzrMJhd+XAT
      24En58cNp6sPRDd+FzOH08uFINevyzKWYxkMgVj+e3fbuiyOB8RqvndKvtfBBcpB
      cCO86lGnj/ETMDciTczUShxaMn9wV1zr1KH1xvT3ohUeOcQZGbGTcjG4mxlns8ZO
      U5J3Yrcd1eMfJq9Bwd3zPsTLnT8LwIS8vfYRav9b34XdqcBG73dhrjsicMK0Qy0z
      Qz7vKJzcvrEnKuaMyB3mCxz/UvbNc2Bupwm4FmzN5eFjDs+7paYFdfOzqMjoRP+8
      bcXSqDN5P2eUd7cdsZXaFNcsf1FkWlE3GudVBOmNJqz9zBab/T5J+l4Z90Pd6OUX
      GNozEvLhcJkvPKA526TegHTGC8hMquxKc9tpOzNRqZJMFa+UG1mgMrMepRmM/B3s
      QrKI1C11iCVYfb9J0tQUkfENHMx4J7mG2DZAhnKWQDU2awM41qU4A7aBYaJvDPnQ
      RRcbaT0D794lKUQwH/mZuyKzF22oZNk1o1TV2SaFXqgX5tDt
      -----END CERTIFICATE-----
      </ca>
    '';
  };
}
