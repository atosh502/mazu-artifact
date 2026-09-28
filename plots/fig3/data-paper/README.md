- new-keypair.data
    The output of running `go test -v -bench=BenchmarkNewKeyPair -benchmem
    -timeout=12h -args -max-users=1000000` for the `etclab/rbe` package

- reg-user.data
    The output of running `go test -v -bench=BenchmarkRegisterUser -benchmem
    -timeout=12h -args -max-users=1000000` for the `etclab/rbe` package

- rbe-genkey-reguser.dat
    Selected data from:
    - new-keypair.data
    - reg-user.data
    made with `python3 format.py new-keypair.data reg-user.data
    rbe-genkey-reguser.dat` (format.py is in the `etclab/rbe` package)
