{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "htmlparser";
  version = "v1.0.0";

  src = fetchFromGitHub {
    owner = "htmlparser";
    repo = "htmlparser";
    rev = "02f964ebd24c296dcfa56c357bb8dedde0f39757";
    sha256 = "1k19rdpjf5sdyjfl233y6bsfgkcnv799ivrh2vkw22almg4243ar";
  };

  vendorSha256 = "0qkd587z4n372y4lqyzjqc1qlsi3525ah99vdm5dqq4jidcd5h7w";
}
