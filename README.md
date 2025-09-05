# ktechnical-lab
![Last Commit](https://img.shields.io/github/last-commit/Kruuxt/ktechnical-lab)
![Issues](https://img.shields.io/github/issues/Kruuxt/ktechnical-lab)
![License](https://img.shields.io/github/license/Kruuxt/ktechnical-lab)
![Repo Size](https://img.shields.io/github/repo-size/Kruuxt/ktechnical-lab)
![Platform](https://img.shields.io/badge/platform-Proxmox-informational?logo=proxmox)

This repository documents the build and evolution of my homelab environment, hosted on a Dell T5810 running Proxmox VE.  
It serves as a platform for experimenting with virtualization, networking, and storage, while enforcing a disciplined process for documentation and change tracking.  

---

## Goals
- Gain practical, hands-on experience with enterprise-like infrastructure.  
- Practice documenting changes, issues, and solutions in a repeatable way.  
- Build a referenceable portfolio of technical projects.  

---

## Current Architecture
- **Hardware**: Dell T5810, GTX 1060, 600GB HDD, 3TB HDD, dual-port NIC  
- **Virtualization**: Proxmox VE  
- **Networking**: OPNsense VM handling routing & firewall (bridge-mode modem)  
- **Storage**: TrueNAS VM (planned)  

**Topology**
TODO
---

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
