{
  ssh-tpm-agent,
}:

ssh-tpm-agent.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./client-pid.patch
  ];
  doCheck = false;
})
