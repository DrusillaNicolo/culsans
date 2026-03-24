make clean
cd tests/integration
rm -rf work
make rtl NB_CORES=2
make sw NB_CORES=2
make GUI=1 -C testlist/ip_module_test/ all

