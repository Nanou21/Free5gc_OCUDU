# Physical 5G SA Testbed with free5GC, OCUDU, and Multi-UPF N9 Chaining

## 1. Introduction

This repository documents a physical **5G Standalone (SA) testbed** integrating a **free5GC core network** with an **OCUDU-based disaggregated RAN** composed of one O-CU and two physical O-DUs.

The testbed uses two **Samsung Galaxy 26** COTS UEs, two USRP B210 radio branches, a shared O-CU, and two UPFs connected through **N9**.

```text
UE1 ---- O-DU1 ----\
                    \
                     O-CU ---- UPF1 ---- N9 ---- UPF2 ---- DN / Internet
                    /
UE2 ---- O-DU2 ----/
```

The SMF controls UPF1 and UPF2 through **N4/PFCP**. The O-CU connects to the AMF through **N2** and to UPF1 through **N3**.

---

## 2. Hardware and Software

| Component | Role / Configuration |
|---|---|
| PC1 | free5GC Core + O-CU |
| PC2 | O-DU1 |
| PC3 | O-DU2 |
| SDR 1 | USRP B210 connected to O-DU1 |
| SDR 2 | USRP B210 connected to O-DU2 |
| UE1 | Samsung Galaxy 26, served by O-DU1 / PCI 1 |
| UE2 | Samsung Galaxy 26, served by O-DU2 / PCI 2 |
| Core/CU OS | Ubuntu — **version to be confirmed from the physical host** |
| DU1 OS | Ubuntu — **version to be confirmed from the physical host** |
| DU2 OS | Ubuntu — **version to be confirmed from the physical host** |
| Core | free5GC |
| RAN | OCUDU |
| SDR driver | UHD |
| Database | MongoDB |
| UPF forwarding | gtp5g |
| Packet validation | tcpdump / tshark |

> The current project files do not record the Ubuntu releases of the three physical OCUDU hosts. Run `lsb_release -d` on PC1, PC2, and PC3 and replace the three placeholders above before publication.

### Addressing

| Node / Interface | Address |
|---|---|
| AMF | `192.168.56.4` |
| O-DU1 | `192.168.56.5` |
| O-DU2 | `192.168.56.6` |
| O-CU F1/N2 | `192.168.56.7` |
| O-CU N3 | `192.168.56.8` |
| SMF PFCP | `10.200.0.1` |
| UPF1 PFCP | `10.200.1.2` |
| UPF2 PFCP | `10.200.2.2` |
| UPF1 N3/N9 | `192.168.56.41` |
| UPF2 N9 | `192.168.56.42` |
| UE pool | `10.60.0.0/16` |

---

## 3. Relevant Configuration

The sections below show the configuration blocks that are directly relevant to the deployed multi-UPF OCUDU testbed.

### 3.1 SMF — `smfcfg.ulcl.yaml`

```yaml
configuration:
  pfcp:
    nodeID: 10.200.0.1
    listenAddr: 10.200.0.1
    externalAddr: 10.200.0.1

  userplaneInformation:
    upNodes:
      gNB1:
        type: AN
        an_ip: 192.168.56.8

      UPF1:
        type: UPF
        nodeID: 10.200.1.2
        addr: 10.200.1.2
        interfaces:
          - interfaceType: N3
            endpoints:
              - 192.168.56.41
            networkInstances:
              - internet
          - interfaceType: N9
            endpoints:
              - 192.168.56.41
            networkInstances:
              - internet

      UPF2:
        type: UPF
        nodeID: 10.200.2.2
        addr: 10.200.2.2
        sNssaiUpfInfos:
          - sNssai:
              sst: 1
              sd:
            dnnUpfInfoList:
              - dnn: internet
                pools:
                  - cidr: 10.60.0.0/16
        interfaces:
          - interfaceType: N3
            endpoints:
              - 192.168.56.42
            networkInstances:
              - internet
          - interfaceType: N9
            endpoints:
              - 192.168.56.42
            networkInstances:
              - internet

    links:
      - A: gNB1
        B: UPF1
      - A: UPF1
        B: UPF2

  ulcl: true
```

The logical access-network node is the O-CU N3 address `192.168.56.8`. The selected user-plane topology is:

```text
gNB1 -> UPF1 -> UPF2
```

### 3.2 UPF1 — `upfcfg01.yaml`

```yaml
version: 1.0.3
description: UPF initial local configuration

pfcp:
  addr: 10.200.1.2
  nodeID: 10.200.1.2
  retransTimeout: 1s
  maxRetrans: 3

gtpu:
  forwarder: gtp5g
  ifList:
    - addr: 192.168.56.41
      type: N3
    - addr: 192.168.56.41
      type: N9

dnnList:
  - dnn: internet
    cidr: 10.60.0.0/16

logger:
  enable: true
  level: info
  reportCaller: false
```

UPF1 is the first user-plane function reached from the O-CU over N3 and also exposes an N9 interface for forwarding traffic toward UPF2.

### 3.3 UPF2 — `upfcfg02.yaml`

```yaml
version: 1.0.3
description: UPF initial local configuration

pfcp:
  addr: 10.200.2.2
  nodeID: 10.200.2.2
  retransTimeout: 1s
  maxRetrans: 3

gtpu:
  forwarder: gtp5g
  ifList:
    - addr: 192.168.56.42
      type: N9

dnnList:
  - dnn: internet
    cidr: 10.60.0.0/16

logger:
  enable: true
  level: info
  reportCaller: false
```

UPF2 receives the inter-UPF traffic over N9 and provides the final user-plane anchor toward the data network.

### 3.4 UE Routing — `uerouting.yaml`

```yaml
info:
  version: 1.0.7
  description: Routing information for UE

ueRoutingInfo:
  UE1:
    members:
      - imsi-001010000000030
    topology:
      - A: gNB1
        B: UPF1
      - A: UPF1
        B: UPF2

    specificPath:
      - dest: 8.8.8.8/32
        # path: [UPF2] is not explicitly enabled

  UE2:
    members:
      - imsi-001010000000062
    topology:
      - A: gNB1
        B: UPF1
      - A: UPF1
        B: UPF2
```

Both Samsung Galaxy 26 UEs therefore use the same configured topology:

```text
gNB1 -> UPF1 -> UPF2
```

### 3.5 O-CU — `cu.yml`

```yaml
ran_node_name: ocucp01
gnb_id: 411
gnb_id_bit_length: 22
gnb_cu_up_id: 0

cu_cp:
  amf:
    addr: 192.168.56.4
    bind_addr: 192.168.56.7
    supported_tracking_areas:
      - tac: 7
        plmn_list:
          - plmn: "00101"
            tai_slice_support_list:
              - sst: 1
                sd: 1122867

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

### 3.6 O-DU1 — `du1.yml`

```yaml
f1ap:
  cu_cp_addr: 192.168.56.7
  bind_addr: 192.168.56.5

f1u:
  socket:
    - bind_addr: 192.168.56.5

ru_sdr:
  device_driver: uhd
  device_args: type=b200
  srate: 23.04
  otw_format: sc12
  tx_gain: 80
  rx_gain: 40

cell_cfg:
  dl_arfcn: 650000
  band: 78
  channel_bandwidth_MHz: 20
  common_scs: 30
  plmn: "00101"
  tac: 1
  pci: 1
```

### 3.7 O-DU2 — `du2.yml`

```yaml
f1ap:
  cu_cp_addr: 192.168.56.7
  bind_addr: 192.168.56.6

f1u:
  socket:
    - bind_addr: 192.168.56.6

ru_sdr:
  device_driver: uhd
  device_args: type=b200,num_recv_frames=64,num_send_frames=64
  clock: internal
  sync: internal
  srate: 23.04
  otw_format: sc12
  tx_gain: 70
  rx_gain: 50

cell_cfg:
  dl_arfcn: 650000
  band: 78
  channel_bandwidth_MHz: 20
  common_scs: 30
  plmn: "00101"
  tac: 7
  nof_antennas_dl: 1
  nof_antennas_ul: 1
  pci: 2
```


## 4. Run the Testbed

The following commands are the only execution commands required in this README. Detailed namespace, routing, and service configuration is contained in the scripts and YAML files.

### 4.1 Create the namespaces

From the directory containing the script:

```bash
sudo bash create_ns.sh
```

### 4.2 Start the free5GC services

```bash
sudo bash start_services.sh
```

### 4.3 Start the O-CU

The O-CU has its own directory. On the O-CU host, enter the CU folder first, then start it with the CU configuration:

```bash
cd CU
sudo ./ocu -c cu.yml
```

### 4.4 Start O-DU1

Both O-DU configurations are stored in the same `DU` directory. On the DU1 host:

```bash
cd du
sudo ./odu -c du1.yml
```

### 4.5 Attach UE1

Enable the private 5G network on the first **Samsung Galaxy 26** and confirm that it attaches to:

```text
O-DU1 / PCI 1
```

### 4.6 Run the UE1 speed test

The preliminary observed throughput was approximately:

```text
~30 Mbps
```

### 4.7 Start O-DU2

On the DU2 host, enter the same `DU` directory and start the second DU with its own configuration:

```bash
cd du
sudo ./odu -c du2.yml
```

### 4.8 Attach UE2

Enable the private 5G network on the second **Samsung Galaxy 26** and confirm that it attaches to:

```text
O-DU2 / PCI 2
```

### 4.9 Run the UE2 speed test

The preliminary observed throughput was approximately:

```text
~30 Mbps
```

---

## 5. Packet Validation

### 5.1 PFCP / N4

```bash
sudo tcpdump -ni any udp port 8805
```

### 5.2 GTP-U / N3 / N9

```bash
sudo tcpdump -ni any udp port 2152
```

### 5.3 Decode GTP-U with tshark

```bash
sudo tshark -i any -n \
  -d udp.port==2152,gtp \
  -f "udp port 2152"
```

The expected uplink path is:

```text
Samsung Galaxy 26
        |
       O-DU
        |
      F1-U
        |
       O-CU
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

Representative outer GTP-U addresses include:

```text
O-DU -> O-CU
192.168.56.5/6 -> 192.168.56.7

O-CU -> UPF1
192.168.56.8 -> 192.168.56.41

UPF1 -> UPF2
192.168.56.41 -> 192.168.56.42
```

---

## 6. Test Sequence

```text
sudo bash create_ns.sh
        |
        v
sudo bash start_services.sh
        |
        v
cd CU
Start O-CU
        |
        v
cd du
Start O-DU1
        |
        v
Attach Samsung Galaxy 26 UE1
        |
        v
Speed test (~30 Mbps)
        |
        v
cd du
Start O-DU2
        |
        v
Attach Samsung Galaxy 26 UE2
        |
        v
Speed test (~30 Mbps)
        |
        v
Run tcpdump / tshark validation
```

---

## 7. Troubleshooting Notes

Important issues encountered during testbed development included:

- IP forwarding between namespaces
- host routes for the UPF GTP-U endpoints
- N9 forwarding between UPF1 and UPF2
- O-DU reachability to the O-CU
- selecting the correct physical NIC for O-DU2
- RF placement and TX-gain tuning to separate the two Samsung Galaxy 26 UEs between PCI 1 and PCI 2
- confirming both UPFs are associated with the SMF over N4 before UE attachment

---

## 8. Repository Structure

```text
.
├── README.md
├── docs/
│   └── free5GC_OCUDU_Report.docx
├── CU/
│   └── cu.yml
├── DU/
│   ├── du1.yml
│   └── du2.yml
├── core_configurations/
│   ├── core/
│   ├── smf/
│   └── upf/
├── scripts/
│   ├── create_ns.sh
│   └── start_services.sh
└── figures/
    └── architecture.png
```

---


## Security Note

Do not commit subscriber authentication keys, OP/OPc values, private keys, certificates, GitHub tokens, or other credentials to a public repository.
