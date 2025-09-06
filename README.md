# KTech Lab
![Last Commit](https://img.shields.io/github/last-commit/Kruuxt/ktechnical-lab)
![Issues](https://img.shields.io/github/issues/Kruuxt/ktechnical-lab)
![License](https://img.shields.io/github/license/Kruuxt/ktechnical-lab)
![Repo Size](https://img.shields.io/github/repo-size/Kruuxt/ktechnical-lab)
![Platform](https://img.shields.io/badge/platform-Proxmox-informational?logo=proxmox)

This repository documents the build and evolution of my homelab environment.  
It serves as a platform for experimenting with virtualization, networking, and storage, while enforcing a disciplined process for documentation and change tracking.  

---

## Goals
- Gain practical, hands-on experience with network infrastructure.  
- Practice documenting changes, issues, and solutions in a repeatable way.  
- Build a referenceable portfolio of technical projects.  

---

## Hardware
**Dell Precision T5810**
- Name: pve1
- CPU: Intel Xeon E5-1650 v4
  - Cores: 6
  - Threads: 12
  - Base/Max Freq.: 3.6/4.0 GHz
  - Cache: 15MB
  - TDP: 140W
- RAM:
  - Capacity: 48GB (3x16)
  - Speed: 2133MHz
  - Type: ECC DDR4 RDIMM
- Disk1: 600GB 7200RPM HDD SATA
- Disk2: 3TB 7200RPM HDD SATA
- GPU: NVIDIA GTX 1060
- PSU: 825W

**Trigkey S5 Mini**
- Name: trigkey
- CPU: Ryzen 5 5500U
  - Cores: 6
  - Threads: 12
  - Base/Max Freq.: 2.1/4.0 GHz
  - Cache: 8MB
  - TDP: 15W
- RAM:
  - Capacity: 16GB (2x8)
  - Speed: 3200MHz
  - Type: DDR4 SODIMM
- Disk1: 500GB M.2 NVME
- GPU: Integrated

**Main Desktop**
- Name: john-desktop
- CPU: Intel Core i9-9900K
  - Cores: 8
  - Threads: 16
  - Base/Max Freq.: 3.6/5.0 GHz
  - Cache: 16MB
  - TDP: 95W
- RAM:
  - Capacity: 32GB (4x8)
  - Speed: 4000MHz
  - Type: DDR4 DIMM
- Disk1: 1TB M.2 NVME (Samsung 970)
- Disk2: 1TB M.2 NVME (Crucial P1)
- GPU: NVIDIA RTX 3090
- PSU: 1600W Titanium (Corsair 1600i)

## Documentation Rules

To keep this repository organized and professional, the following rules apply:

### Logs
- Every major change, issue, or experiment must be logged in `/logs/` as a dated markdown file (`YYYY-MM-DD.md`).  
- Logs should include:  
  - **What was attempted or changed**  
  - **Problems encountered**  
  - **Solutions applied**  
  - **Next steps or follow-ups**  

### Issues
- **When to open an Issue**:  
  - Hardware or software tasks not yet completed  
  - Bugs or configuration problems discovered during testing  
  - Planned improvements or features (e.g., VLAN setup, monitoring)  
- **When to close an Issue**:  
  - Once resolved, with a clear note on the fix or outcome  
  - Links to relevant configs, logs, or commits must be included in the closing comment  

### Milestones
- Used to group related issues into phases of work (e.g., *Initial Deployment*, *Networking Buildout*, *Storage & Backup*).  
- Closed once all related issues are resolved.  

### Configs
- All configs must be placed under `/configs/` in subfolders (Proxmox, OPNsense, TrueNAS, etc.).  
- Sensitive values (passwords, keys, private IPs) must be sanitized before commit.  
- Each config commit should include a short description of **what changed and why**.  

### Diagrams
- Updated diagrams must be stored in `/diagrams/` with a date in the filename.  
- Any topology or architectural change must be reflected in an updated diagram.  

### Commits
- Commits should follow the format:  
  `[component]: short description`  
  Examples:  
  - `network: added OPNsense VM config`  
  - `docs: logged setup on 2025-09-03`  
  - `hardware: installed dual-port NIC`  

---

## Skills Demonstrated
- Virtualization (Proxmox VE)  
- Networking (OPNsense firewall, subnetting, bridge mode modem)  
- Storage & filesystems (TrueNAS, ZFS pools)  
- Linux administration (kernel module troubleshooting, driver installation)  
- Documentation & version control (GitHub workflow, Issues, milestones, project boards)  

---

## Roadmap
- [ ] Configure VLANs for segmented networks  
- [ ] Deploy TrueNAS VM and create storage pools  
- [ ] Implement centralized logging & monitoring  
- [ ] Experiment with Docker/Kubernetes cluster  
- [ ] Test backup and restore procedures
