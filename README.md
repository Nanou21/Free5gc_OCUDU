# Physical 5G SA Testbed with free5GC, OCUDU, and Multi-UPF N9 Chaining

This repository documents a physical **5G Standalone (SA) testbed** integrating a **free5GC core network** with an **OCUDU-based disaggregated RAN** consisting of one O-CU and two physical O-DUs.

The testbed supports two COTS UEs, two USRP B210 radio branches, a shared O-CU, and a dual-UPF user-plane topology in which traffic is forwarded from **UPF1 to UPF2 over N9** before reaching the external data network.

The repository contains configuration files, namespace and service-startup scripts, architecture documentation, and validation procedures intended to support reproducibility and future work on **network automation and intent-driven networking**.

---

## 1. Testbed Overview

The deployment is distributed across three physical PCs:

| Node | Role | Main Address / Hardware |
|---|---|---|
| PC1 | free5GC Core + O-CU | AMF: `192.168.56.4`, CU F1/N2: `192.168.56.7`, CU N3: `192.168.56.8` |
| PC2 | O-DU1 | `192.168.56.5`, USRP B210 |
| PC3 | O-DU2 | `192.168.56.6`, USRP B210 |
| UE1 | COTS UE | Served by DU1 / PCI 1 |
| UE2 | COTS UE | Served by DU2 / PCI 2 |

The RAN and core are connected through the `192.168.56.0/24` network.

---

## 2. Architecture

The current end-to-end topology is:

```text
UE1                    UE2
 |                      |
NR-Uu                  NR-Uu
 |                      |
O-DU1                  O-DU2
192.168.56.5           192.168.56.6
PCI 1                  PCI 2
   \                    /
    \      F1-C/U      /
     \                /
        O-CU
   F1/N2: 192.168.56.7
   N3:    192.168.56.8
          |
          | N2
          +--------------------> AMF
          |                       192.168.56.4
          |
          | N3
          v
        UPF1
   PFCP: 10.200.1.2
   GTP-U: 192.168.56.41
          |
          | N9
          v
        UPF2
   PFCP: 10.200.2.2
   GTP-U: 192.168.56.42
          |
          | N6
          v
   Data Network / Internet
```

The SMF controls both UPFs over **N4/PFCP** using:

```text
SMF PFCP: 10.200.0.1
    |
    +---- N4 ----> UPF1: 10.200.1.2
    |
    +---- N4 ----> UPF2: 10.200.2.2
```

---

## 3. Main Interfaces

| Interface | Endpoints | Function |
|---|---|---|
| NR-Uu | UE ↔ O-DU | Radio access |
| F1-C | O-DU ↔ O-CU | F1AP control signaling |
| F1-U | O-DU ↔ O-CU | GTP-U user-plane forwarding |
| N2 | O-CU ↔ AMF | NGAP control signaling |
| N3 | O-CU ↔ UPF1 | GTP-U user plane |
| N4 | SMF ↔ UPF1 / UPF2 | PFCP session control |
| N9 | UPF1 ↔ UPF2 | Inter-UPF GTP-U forwarding |
| N6 | UPF2 ↔ Data Network | External data-network access |

---

## 4. RAN Configuration

### O-CU

The current O-CU uses:

```yaml
ran_node_name: ocucp01
gnb_id: 411
gnb_id_bit_length: 22
gnb_cu_up_id: 0

cu_cp:
  amf:
    addr: 192.168.56.4
    bind_addr: 192.168.56.7
  f1ap:
    bind_addr: 192.168.56.7

cu_up:
  f1u:
    socket:
      - bind_addr: 192.168.56.7
  ngu:
    socket:
      - bind_addr: 192.168.56.8
```

The configured PLMN is `00101`, with SST `1` and SD `0x112233`.

---

### O-DU1

```yaml
f1ap:
  cu_cp_addr: 192.168.56.7
  bind_addr: 192.168.56.5

f1u:
  socket:
    - bind_addr: 192.168.56.5

cell_cfg:
  dl_arfcn: 650000
  band: 78
  channel_bandwidth_MHz: 20
  common_scs: 30
  plmn: "00101"
  tac: 1
  pci: 1
```

Observed RF settings:

```yaml
tx_gain: 80
rx_gain: 40
```

---

### O-DU2

```yaml
f1ap:
  cu_cp_addr: 192.168.56.7
  bind_addr: 192.168.56.6

f1u:
  socket:
    - bind_addr: 192.168.56.6

cell_cfg:
  dl_arfcn: 650000
  band: 78
  channel_bandwidth_MHz: 20
  common_scs: 30
  plmn: "00101"
  tac: 7
  pci: 2
  nof_antennas_dl: 1
  nof_antennas_ul: 1
```

Observed RF settings:

```yaml
clock: internal
sync: internal
tx_gain: 70
rx_gain: 50
```

> The current DU screenshots explicitly show the PCI values, but do not show separate `sector_id` or `nr_cell_id` values.

---

## 5. free5GC User-Plane Configuration

### SMF

The SMF PFCP endpoint is:

```yaml
pfcp:
  nodeID: 10.200.0.1
  listenAddr: 10.200.0.1
  externalAddr: 10.200.0.1
```

The logical access-network node is the O-CU N3 endpoint:

```yaml
userplaneInformation:
  upNodes:
    gNB1:
      type: AN
      an_ip: 192.168.56.8
```

UPF1 and UPF2 are connected as:

```yaml
links:
  - A: gNB1
    B: UPF1

  - A: UPF1
    B: UPF2

ulcl: true
```

---

### UPF1

```yaml
nodeID: 10.200.1.2
PFCP:   10.200.1.2
N3/N9:  192.168.56.41
```

UPF1 receives N3 traffic from the O-CU and forwards traffic toward UPF2 over N9.

---

### UPF2

```yaml
nodeID: 10.200.2.2
PFCP:   10.200.2.2
N9:     192.168.56.42
UE pool: 10.60.0.0/16
```

UPF2 acts as the final user-plane anchor and provides N6 breakout toward the data network.

---

## 6. UE Routing

The current `uerouting.yaml` assigns both UEs to the same user-plane chain.

### UE1

```yaml
UE1:
  members:
    - imsi-001010000000030

  topology:
    - A: gNB1
      B: UPF1

    - A: UPF1
      B: UPF2
```

### UE2

```yaml
UE2:
  members:
    - imsi-001010000000062

  topology:
    - A: gNB1
      B: UPF1

    - A: UPF1
      B: UPF2
```

The resulting logical path is:

```text
gNB1 -> UPF1 -> UPF2
```

---

## 7. Linux Namespace Design

The UPFs and data-network functions are isolated using Linux network namespaces.

```text
Root Namespace
 |
 |-- upf1ns
 |    |-- PFCP: 10.200.1.2
 |    `-- GTP-U: 192.168.56.41
 |
 |-- upf2ns
 |    |-- PFCP: 10.200.2.2
 |    |-- GTP-U: 192.168.56.42
 |    `-- N6: 10.100.0.254/24
 |
 `-- dn2ns
      |-- 10.100.0.1/24
      `-- 10.101.0.2/30
```

The host provides Internet access through `wlp15s0`.

Example NAT rule:

```bash
sudo iptables -t nat -A POSTROUTING \
  -s 10.60.0.0/16 \
  -o wlp15s0 \
  -j MASQUERADE
```

IPv4 forwarding must be enabled in the root namespace and forwarding namespaces.

---

## 8. Repository Structure

```text
.
├── README.md
├── docs/
│   └── free5GC_OCUDU_Report.docx
├── configs/
│   ├── cu/
│   │   └── cu.yml
│   ├── du/
│   │   ├── du1.yml
│   │   └── du2.yml
│   ├── smf/
│   │   ├── smfcfg.ulcl.yaml
│   │   └── uerouting.yaml
│   └── upf/
│       ├── upfcfg01.yaml
│       └── upfcfg02.yaml
├── scripts/
│   ├── create_ns.sh
│   └── start_services.sh
├── figures/
│   └── architecture.png
└── captures/
    └── README.md
```

---

## 9. Recommended Startup Sequence

A clean test run should follow this order:

```text
1. Create namespaces, veth pairs, routes, and forwarding rules
2. Start MongoDB
3. Start free5GC control-plane NFs
4. Start UPF1
5. Start UPF2
6. Start SMF
7. Confirm PFCP associations with both UPFs
8. Start O-CU
9. Start O-DU1
10. Attach UE1
11. Start O-DU2
12. Attach UE2
13. Validate N3, N9, and N6 traffic
14. Run end-to-end throughput tests
```

---

## 10. Validation

The testbed has been validated using:

- free5GC NF logs
- O-CU and O-DU logs
- PFCP session-establishment and modification logs
- `tcpdump`
- `tshark`
- GTP-U packet inspection
- COTS UE Internet connectivity
- end-to-end speed tests

A representative observed user-plane route is:

```text
UE
 |
O-DU
 |
F1-U
 |
O-CU / CU-UP
 |
N3
 |
UPF1
 |
N9
 |
UPF2
 |
N6
 |
Internet
```

Packet captures have shown traffic on the N3 and N9 GTP-U paths.

---

## 11. Preliminary Throughput

Initial end-to-end COTS UE testing produced approximately:

| UE | Serving O-DU | Approximate Download Throughput |
|---|---|---|
| UE1 | O-DU1 / PCI 1 | ~30 Mbps |
| UE2 | O-DU2 / PCI 2 | ~30 Mbps |

These values are preliminary observations rather than controlled performance benchmarks.

---

## 12. Useful Validation Commands

### Check PFCP

```bash
sudo tcpdump -ni any udp port 8805
```

### Check GTP-U

```bash
sudo tshark -i any -n \
  -d udp.port==2152,gtp \
  -f "udp port 2152"
```

### Check namespace addresses

```bash
sudo ip netns exec upf1ns ip addr
sudo ip netns exec upf2ns ip addr
sudo ip netns exec dn2ns ip addr
```

### Check routing

```bash
sudo ip netns exec upf1ns ip route
sudo ip netns exec upf2ns ip route
sudo ip netns exec dn2ns ip route
ip route
```

### Check PFCP listeners

```bash
sudo ip netns exec upf1ns ss -lunp | grep 8805
sudo ip netns exec upf2ns ss -lunp | grep 8805
```

---

## 13. Troubleshooting Notes

### O-DU cannot reach O-CU

Verify Layer-2/Layer-3 reachability before debugging F1AP.

```bash
ping 192.168.56.7
```

### Both UEs attach to the same O-DU

Different PCIs identify the cells but do not force UE association. RF placement and transmit-gain tuning may be required to isolate each UE to the desired radio branch.

### N9 traffic is not visible

Verify:

- both UPFs are associated with the SMF over N4
- UPF1 exposes the N9 endpoint `192.168.56.41`
- UPF2 exposes the N9 endpoint `192.168.56.42`
- the SMF topology includes `UPF1 -> UPF2`
- the host contains the required routes to both GTP-U endpoints

### SMF reaches `EstablishPSA2()` and panics

When using the current preconfigured ULCL path, verify that both UPFs are active and associated with the SMF before UE attachment. A missing UPF or incomplete runtime state can cause the ULCL/PSA2 procedure to fail even when the configuration itself has not changed.

---

## 14. Research Direction

This testbed is intended to provide a physical experimentation platform for research in:

- 5G and beyond-5G network automation
- intent-driven networking
- automated configuration management
- multi-UPF path orchestration
- policy-aware user-plane steering
- RAN/core coordination
- dynamic network reconfiguration
- security-aware 5G core management

A longer-term objective is to use the testbed as a controlled environment in which an automated or agentic system can translate high-level network requirements into validated configuration changes across the RAN and core.

---

## 15. Reproducibility Notes

Before using the repository in another environment, update values that are deployment-specific, including:

- physical NIC names
- Internet-facing interface
- RAN/core subnet
- O-CU and O-DU addresses
- USRP device settings
- RF gain values
- subscriber IMSIs
- UE address pool
- PFCP namespace addresses

Do not commit private keys, certificates, credentials, subscriber secrets, or other sensitive configuration values.

---

## 16. Status

Current validated capabilities include:

- [x] free5GC core operation
- [x] physical O-CU/O-DU RAN integration
- [x] two physical O-DUs
- [x] two COTS UE attachments
- [x] separate PCI values for both radio branches
- [x] N2 connectivity
- [x] N3 connectivity
- [x] dual-UPF deployment
- [x] N4 PFCP control
- [x] N9 inter-UPF connectivity
- [x] N6 Internet breakout
- [x] end-to-end COTS UE data connectivity
- [x] packet-level path validation
- [x] preliminary throughput testing

---

## License

Add the appropriate license for your project before public release.

If this repository contains code or configuration derived from third-party projects, retain their original copyright and license notices where required.
