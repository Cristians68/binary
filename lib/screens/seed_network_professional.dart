import 'package:cloud_firestore/cloud_firestore.dart';

/// Run this once to seed the Binary Network Professional course.
/// Call: await seedNetworkProfessional();
Future<void> seedNetworkProfessional() async {
  final db = FirebaseFirestore.instance;
  final courseRef = db.collection('courses').doc('binary-network-professional');

  await courseRef.set({
    'title': 'Network Professional',
    'subtitle': 'Master modern networking from fundamentals to advanced design',
    'tag': 'Binary Network Pro',
    'color': 0xFF3B82F6,
    'order': 4,
    'isComingSoon': false,
    'progress': 0.0,
    'totalModules': 20,
    'description':
        'A comprehensive, exam-ready course covering everything from the OSI model to enterprise network design, security, and cloud networking. Built for learners with some IT background who want to become network professionals.',
  });

  final modules = [
    {
      'order': 1,
      'title': 'Introduction to Networking',
      'subtitle': 'What networks are and why they matter',
      'status': 'active',
      'content': '''
# Introduction to Networking

A **network** is a collection of devices connected together to share resources and communicate. Networks power everything from sending an email to streaming video, running cloud applications, and enabling global commerce.

## Why Networking Matters
Understanding networking is foundational to virtually every IT role. Whether you're in security, cloud, development, or support, network knowledge underpins your work.

## Types of Networks
- **LAN (Local Area Network):** Covers a small geographic area like an office or home. Fast, privately owned.
- **WAN (Wide Area Network):** Spans large distances, often connecting multiple LANs. The internet is the largest WAN.
- **MAN (Metropolitan Area Network):** City-wide network, often used by ISPs or governments.
- **PAN (Personal Area Network):** Very short range, like Bluetooth between your phone and headphones.
- **WLAN (Wireless LAN):** A LAN using wireless connections (Wi-Fi).

## Network Topologies
Topology describes how devices are physically or logically arranged:
- **Bus:** All devices share a single cable. Simple but prone to failure.
- **Star:** All devices connect to a central switch or hub. Most common in modern LANs.
- **Ring:** Devices connected in a circular loop. Data travels in one direction.
- **Mesh:** Every device connects to every other device. Highly redundant, used in critical systems.
- **Hybrid:** Combination of two or more topologies.

## Key Networking Devices
- **Hub:** Broadcasts data to all devices. Outdated.
- **Switch:** Sends data only to the intended device using MAC addresses.
- **Router:** Connects different networks and routes traffic between them using IP addresses.
- **Access Point (AP):** Provides wireless connectivity to a wired network.
- **Modem:** Converts digital signals to analog (and back) for transmission over phone or cable lines.

## Network Components
- **NIC (Network Interface Card):** Hardware that connects a device to a network.
- **Cable:** Physical medium — copper (Ethernet) or fiber optic.
- **Firewall:** Filters traffic based on rules to protect the network.

Understanding these basics gives you the vocabulary and mental model for everything that follows in this course.
''',
      'quizQuestions': [
        {
          'question': 'Which network type covers the largest geographic area?',
          'options': ['LAN', 'PAN', 'WAN', 'WLAN'],
          'correctIndex': 2,
          'explanation':
              'WAN (Wide Area Network) spans large distances and can cover entire countries or the globe. The internet itself is a WAN.',
        },
        {
          'question':
              'Which topology connects all devices to a central switch?',
          'options': ['Bus', 'Ring', 'Mesh', 'Star'],
          'correctIndex': 3,
          'explanation':
              'Star topology uses a central device (switch or hub) that all other devices connect to. It is the most common topology in modern LANs.',
        },
        {
          'question':
              'What device uses MAC addresses to send data only to the intended recipient?',
          'options': ['Hub', 'Router', 'Switch', 'Modem'],
          'correctIndex': 2,
          'explanation':
              'A switch maintains a MAC address table and forwards frames only to the port associated with the destination MAC address.',
        },
        {
          'question': 'What does NIC stand for?',
          'options': [
            'Network Interface Card',
            'Network Internet Controller',
            'Node Interface Component',
            'Network Internal Cable',
          ],
          'correctIndex': 0,
          'explanation':
              'NIC stands for Network Interface Card — the hardware component that connects a device to a network.',
        },
        {
          'question': 'Which topology provides the highest redundancy?',
          'options': ['Bus', 'Star', 'Ring', 'Mesh'],
          'correctIndex': 3,
          'explanation':
              'Mesh topology connects every device to every other device, providing multiple paths for data and maximum redundancy.',
        },
      ],
    },
    {
      'order': 2,
      'title': 'The OSI Model',
      'subtitle': 'Understanding the 7-layer networking framework',
      'status': 'locked',
      'content': '''
# The OSI Model

The **OSI (Open Systems Interconnection) model** is a conceptual framework that standardizes how different network systems communicate. It breaks communication into **7 distinct layers**, each with specific responsibilities.

## Why the OSI Model Matters
It gives network engineers a common language for troubleshooting, designing, and understanding how data travels from one device to another.

## The 7 Layers (Top to Bottom)

### Layer 7 — Application
The layer closest to the user. It provides network services directly to applications.
- Protocols: HTTP, HTTPS, FTP, SMTP, DNS, DHCP
- Example: Your browser requesting a web page

### Layer 6 — Presentation
Translates data between the application layer and the network. Handles encryption, compression, and data formatting.
- Example: SSL/TLS encryption, JPEG compression

### Layer 5 — Session
Manages sessions (connections) between applications. Establishes, maintains, and terminates connections.
- Example: Login sessions, video call connections

### Layer 4 — Transport
Ensures reliable (or fast) data delivery. Segments data and reassembles it at the destination.
- Protocols: TCP (reliable), UDP (fast, no guarantee)
- Handles: Port numbers, flow control, error correction

### Layer 3 — Network
Handles logical addressing and routing between networks.
- Protocols: IP (IPv4, IPv6), ICMP, routing protocols
- Devices: Routers
- Example: Determining the best path for a packet

### Layer 2 — Data Link
Handles physical addressing (MAC addresses) and node-to-node communication on the same network segment.
- Protocols: Ethernet, Wi-Fi (802.11), ARP
- Devices: Switches, bridges
- Divided into: LLC (Logical Link Control) and MAC sublayers

### Layer 1 — Physical
The actual physical transmission of raw bits over a medium.
- Includes: Cables, connectors, electrical signals, fiber optics, radio waves
- Devices: Hubs, repeaters, cables

## Memory Trick
**"All People Seem To Need Data Processing"** (top to bottom: Application, Presentation, Session, Transport, Network, Data Link, Physical)

Or bottom to top: **"Please Do Not Throw Sausage Pizza Away"**

## Data Encapsulation
As data moves down the OSI layers from sender to receiver, each layer adds its own header (and sometimes trailer) — this is called **encapsulation**. The receiving device **decapsulates** in reverse order.

| Layer | Data Unit (PDU) |
|-------|----------------|
| Application/Presentation/Session | Data |
| Transport | Segment |
| Network | Packet |
| Data Link | Frame |
| Physical | Bits |
''',
      'quizQuestions': [
        {
          'question': 'At which OSI layer does routing between networks occur?',
          'options': [
            'Layer 2 - Data Link',
            'Layer 3 - Network',
            'Layer 4 - Transport',
            'Layer 5 - Session',
          ],
          'correctIndex': 1,
          'explanation':
              'Layer 3 (Network) handles logical addressing and routing. Routers operate at this layer using IP addresses.',
        },
        {
          'question': 'Which protocol operates at the Transport layer?',
          'options': ['IP', 'HTTP', 'TCP', 'Ethernet'],
          'correctIndex': 2,
          'explanation':
              'TCP (Transmission Control Protocol) operates at Layer 4 (Transport), providing reliable, ordered delivery of data.',
        },
        {
          'question':
              'What is the PDU (Protocol Data Unit) at the Network layer called?',
          'options': ['Frame', 'Segment', 'Packet', 'Bit'],
          'correctIndex': 2,
          'explanation':
              'At the Network layer (Layer 3), the PDU is called a packet. It contains source and destination IP addresses.',
        },
        {
          'question': 'Which layer handles MAC addresses?',
          'options': ['Physical', 'Data Link', 'Network', 'Transport'],
          'correctIndex': 1,
          'explanation':
              'The Data Link layer (Layer 2) uses MAC addresses for node-to-node communication on the same network segment.',
        },
        {
          'question': 'SSL/TLS encryption is associated with which OSI layer?',
          'options': ['Application', 'Presentation', 'Session', 'Transport'],
          'correctIndex': 1,
          'explanation':
              'The Presentation layer (Layer 6) handles data translation, encryption, and compression — SSL/TLS operates here.',
        },
      ],
    },
    {
      'order': 3,
      'title': 'TCP/IP Model & Protocols',
      'subtitle': 'The real-world networking stack',
      'status': 'locked',
      'content': '''
# TCP/IP Model & Protocols

While the OSI model is a conceptual framework, the **TCP/IP model** is what the internet actually runs on. It has **4 layers** that map roughly to the OSI model.

## TCP/IP Layers

| TCP/IP Layer | OSI Equivalent | Key Protocols |
|---|---|---|
| Application | Layers 5-7 | HTTP, HTTPS, FTP, SMTP, DNS, DHCP, SSH |
| Transport | Layer 4 | TCP, UDP |
| Internet | Layer 3 | IP, ICMP, ARP |
| Network Access | Layers 1-2 | Ethernet, Wi-Fi |

## TCP vs UDP

### TCP (Transmission Control Protocol)
- **Connection-oriented:** Establishes a connection before sending data (3-way handshake)
- **Reliable:** Guarantees delivery, order, and error checking
- **Slower** due to overhead
- Used for: Web browsing, email, file transfers

**3-Way Handshake:**
1. SYN — Client sends synchronization request
2. SYN-ACK — Server acknowledges and responds
3. ACK — Client confirms, connection established

### UDP (User Datagram Protocol)
- **Connectionless:** Sends data without establishing a connection
- **Unreliable:** No guarantee of delivery or order
- **Faster** due to low overhead
- Used for: Video streaming, gaming, DNS, VoIP

## Key Application Layer Protocols

| Protocol | Port | Purpose |
|---|---|---|
| HTTP | 80 | Web traffic (unencrypted) |
| HTTPS | 443 | Secure web traffic |
| FTP | 20/21 | File transfer |
| SSH | 22 | Secure remote access |
| Telnet | 23 | Remote access (unencrypted) |
| SMTP | 25 | Sending email |
| DNS | 53 | Domain name resolution |
| DHCP | 67/68 | Automatic IP assignment |
| POP3 | 110 | Receiving email |
| IMAP | 143 | Email access (server-side) |
| SNMP | 161 | Network monitoring |
| RDP | 3389 | Remote desktop |

## ICMP (Internet Control Message Protocol)
Used for diagnostic and error-reporting. The **ping** command uses ICMP Echo Request/Reply to test connectivity. **Traceroute** uses ICMP to map the path packets take.

## ARP (Address Resolution Protocol)
Resolves IP addresses to MAC addresses on a local network. When a device knows the IP but not the MAC, it broadcasts an ARP request. The device with that IP replies with its MAC address.
''',
      'quizQuestions': [
        {
          'question': 'Which port does HTTPS use?',
          'options': ['80', '22', '443', '8080'],
          'correctIndex': 2,
          'explanation':
              'HTTPS uses port 443. It is the secure version of HTTP, using TLS/SSL encryption for web traffic.',
        },
        {
          'question': 'Which protocol resolves IP addresses to MAC addresses?',
          'options': ['DNS', 'DHCP', 'ARP', 'ICMP'],
          'correctIndex': 2,
          'explanation':
              'ARP (Address Resolution Protocol) resolves known IP addresses to their corresponding MAC addresses on a local network.',
        },
        {
          'question':
              'What does the first step (SYN) of the TCP 3-way handshake do?',
          'options': [
            'Terminates the connection',
            'Sends data',
            'Initiates a connection request',
            'Acknowledges receipt',
          ],
          'correctIndex': 2,
          'explanation':
              'SYN (Synchronize) is the first step of the TCP 3-way handshake where the client initiates a connection request to the server.',
        },
        {
          'question':
              'Which protocol would you use for real-time video streaming?',
          'options': ['TCP', 'FTP', 'UDP', 'SMTP'],
          'correctIndex': 2,
          'explanation':
              'UDP is preferred for real-time video streaming because its low overhead and speed are more important than guaranteed delivery.',
        },
        {
          'question': 'Which command uses ICMP to test network connectivity?',
          'options': ['traceroute', 'nslookup', 'ping', 'netstat'],
          'correctIndex': 2,
          'explanation':
              'The ping command uses ICMP Echo Request and Echo Reply messages to test whether a remote host is reachable.',
        },
      ],
    },
    {
      'order': 4,
      'title': 'IP Addressing & Subnetting',
      'subtitle': 'IPv4, IPv6, CIDR, and subnet calculations',
      'status': 'locked',
      'content': '''
# IP Addressing & Subnetting

IP addresses are the logical addresses that identify devices on a network. Understanding IP addressing and subnetting is one of the most critical skills for any network professional.

## IPv4 Addressing
IPv4 addresses are **32-bit** numbers written in **dotted decimal notation**: four octets separated by dots.
Example: **192.168.1.100**

Each octet ranges from 0–255.

### IPv4 Address Classes
| Class | Range | Default Subnet Mask | Use |
|---|---|---|---|
| A | 1.0.0.0 – 126.255.255.255 | 255.0.0.0 (/8) | Large networks |
| B | 128.0.0.0 – 191.255.255.255 | 255.255.0.0 (/16) | Medium networks |
| C | 192.0.0.0 – 223.255.255.255 | 255.255.255.0 (/24) | Small networks |
| D | 224.0.0.0 – 239.255.255.255 | N/A | Multicast |
| E | 240.0.0.0 – 255.255.255.255 | N/A | Reserved/Experimental |

### Private IP Ranges (RFC 1918)
Not routable on the public internet:
- **10.0.0.0 – 10.255.255.255** (/8)
- **172.16.0.0 – 172.31.255.255** (/12)
- **192.168.0.0 – 192.168.255.255** (/16)

### Special Addresses
- **127.0.0.1** — Loopback (localhost), used to test the local network stack
- **0.0.0.0** — Unspecified address
- **255.255.255.255** — Limited broadcast

## Subnetting
Subnetting divides a network into smaller sub-networks (subnets) for organization, security, and efficiency.

### Subnet Mask
Defines which portion of the IP address is the **network** portion and which is the **host** portion.
- **255.255.255.0** = /24 = 256 addresses, 254 usable hosts
- **255.255.255.128** = /25 = 128 addresses, 126 usable hosts

### CIDR Notation
CIDR (Classless Inter-Domain Routing) uses a slash followed by the number of network bits:
- 192.168.1.0**/24** — 24 bits for network, 8 bits for hosts
- 10.0.0.0**/8** — 8 bits for network, 24 bits for hosts

### Subnetting Formula
- **Number of hosts per subnet** = 2^(host bits) - 2
- **Number of subnets** = 2^(borrowed bits)

### Quick Reference
| CIDR | Subnet Mask | Hosts |
|---|---|---|
| /24 | 255.255.255.0 | 254 |
| /25 | 255.255.255.128 | 126 |
| /26 | 255.255.255.192 | 62 |
| /27 | 255.255.255.224 | 30 |
| /28 | 255.255.255.240 | 14 |
| /29 | 255.255.255.248 | 6 |
| /30 | 255.255.255.252 | 2 |

## IPv6
IPv6 uses **128-bit** addresses written in hexadecimal: **2001:0db8:85a3:0000:0000:8a2e:0370:7334**

### Key Features
- Virtually unlimited addresses (3.4 × 10^38)
- No need for NAT
- Built-in IPSec support
- Simplified header

### IPv6 Address Types
- **Unicast:** One-to-one
- **Multicast:** One-to-many
- **Anycast:** One-to-nearest

### Shortening IPv6
- Remove leading zeros in each group
- Replace consecutive all-zero groups with ::  (only once)
- 2001:0db8:0000:0000:0000:0000:0000:0001 → 2001:db8::1
''',
      'quizQuestions': [
        {
          'question': 'How many usable host addresses are in a /26 subnet?',
          'options': ['30', '62', '64', '126'],
          'correctIndex': 1,
          'explanation':
              'A /26 has 6 host bits. 2^6 = 64 addresses, minus 2 (network and broadcast) = 62 usable hosts.',
        },
        {
          'question': 'Which IP address range is private (RFC 1918)?',
          'options': [
            '8.8.8.0/24',
            '172.16.0.0/12',
            '100.0.0.0/8',
            '200.0.0.0/8',
          ],
          'correctIndex': 1,
          'explanation':
              '172.16.0.0/12 is one of three private IP ranges defined in RFC 1918, not routable on the public internet.',
        },
        {
          'question': 'What is the loopback address in IPv4?',
          'options': ['192.168.0.1', '0.0.0.0', '127.0.0.1', '255.255.255.255'],
          'correctIndex': 2,
          'explanation':
              '127.0.0.1 is the loopback address, used to test the local network stack without sending traffic over the network.',
        },
        {
          'question': 'How many bits are in an IPv6 address?',
          'options': ['32', '64', '96', '128'],
          'correctIndex': 3,
          'explanation':
              'IPv6 uses 128-bit addresses, compared to IPv4\'s 32-bit addresses, providing vastly more address space.',
        },
        {
          'question': 'What does CIDR stand for?',
          'options': [
            'Classless Inter-Domain Routing',
            'Class Internet Domain Routing',
            'Central IP Domain Registry',
            'Classful Internet Data Routing',
          ],
          'correctIndex': 0,
          'explanation':
              'CIDR stands for Classless Inter-Domain Routing. It replaced classful networking and uses prefix length notation (e.g., /24).',
        },
      ],
    },
    {
      'order': 5,
      'title': 'Switching & VLANs',
      'subtitle': 'How switches work and network segmentation',
      'status': 'locked',
      'content': '''
# Switching & VLANs

Switches are the backbone of modern LANs. Understanding how they work — and how to segment networks with VLANs — is essential for any network professional.

## How Switches Work

A switch operates at **Layer 2 (Data Link)** of the OSI model. It uses **MAC addresses** to forward frames to the correct port.

### MAC Address Table
Also called a **CAM (Content Addressable Memory) table**, it maps MAC addresses to switch ports.

**How it's built:**
1. When a frame arrives, the switch records the **source MAC** and the **port** it came in on
2. The switch looks up the **destination MAC** in the table
3. If found — forwards only to that port (**unicast**)
4. If not found — floods to all ports except the source (**unknown unicast flood**)
5. Broadcasts are always flooded to all ports

### Switch vs Hub
| Feature | Hub | Switch |
|---|---|---|
| Layer | 1 | 2 |
| Addressing | None | MAC |
| Forwarding | Broadcasts to all | Sends to specific port |
| Collisions | Yes | No (full duplex) |

## VLANs (Virtual Local Area Networks)

A **VLAN** logically segments a physical network into multiple separate broadcast domains — without needing separate physical hardware.

### Why VLANs?
- **Security:** Isolate sensitive departments (e.g., Finance from HR)
- **Performance:** Reduce broadcast traffic
- **Flexibility:** Group devices by function, not location
- **Simplicity:** Easier network management

### VLAN Types
- **Data VLAN:** Carries user-generated traffic
- **Voice VLAN:** Dedicated to VoIP traffic (QoS priority)
- **Management VLAN:** Used for switch management traffic
- **Native VLAN:** Untagged traffic on a trunk port (default VLAN 1)

### Access vs Trunk Ports
- **Access Port:** Belongs to a single VLAN. Connects end devices (PCs, printers).
- **Trunk Port:** Carries traffic for multiple VLANs. Connects switches to switches or switches to routers. Uses **802.1Q tagging** to identify which VLAN each frame belongs to.

### Inter-VLAN Routing
Devices in different VLANs cannot communicate by default. To route between VLANs you need:
- **Router-on-a-stick:** One router port with subinterfaces for each VLAN
- **Layer 3 switch:** A switch with routing capability built in

## Spanning Tree Protocol (STP)
STP (IEEE 802.1D) prevents **switching loops** by blocking redundant paths and only activating them if the primary path fails.

**STP Port States:**
1. Blocking
2. Listening
3. Learning
4. Forwarding
5. Disabled

Modern networks often use **RSTP (Rapid STP / 802.1w)** which converges much faster than original STP.
''',
      'quizQuestions': [
        {
          'question':
              'What table does a switch use to make forwarding decisions?',
          'options': [
            'Routing table',
            'ARP table',
            'MAC address table',
            'IP table',
          ],
          'correctIndex': 2,
          'explanation':
              'A switch uses a MAC address table (CAM table) that maps MAC addresses to specific ports to make forwarding decisions.',
        },
        {
          'question':
              'What happens when a switch receives a frame with an unknown destination MAC?',
          'options': [
            'Drops the frame',
            'Sends to default gateway',
            'Floods all ports except source',
            'Returns an error',
          ],
          'correctIndex': 2,
          'explanation':
              'When the destination MAC is not in the CAM table, the switch floods the frame out all ports except the one it was received on.',
        },
        {
          'question': 'What protocol tags VLAN information on trunk ports?',
          'options': ['802.3', '802.1Q', '802.11', '802.1D'],
          'correctIndex': 1,
          'explanation':
              '802.1Q is the IEEE standard for VLAN tagging on trunk ports, adding a 4-byte tag to Ethernet frames to identify the VLAN.',
        },
        {
          'question': 'What is the purpose of Spanning Tree Protocol?',
          'options': [
            'Assign IP addresses',
            'Encrypt VLAN traffic',
            'Prevent switching loops',
            'Route between VLANs',
          ],
          'correctIndex': 2,
          'explanation':
              'STP prevents switching loops in networks with redundant paths by blocking certain ports and only enabling them if the primary path fails.',
        },
        {
          'question': 'Which port type carries traffic for multiple VLANs?',
          'options': [
            'Access port',
            'Native port',
            'Management port',
            'Trunk port',
          ],
          'correctIndex': 3,
          'explanation':
              'Trunk ports carry traffic for multiple VLANs simultaneously using 802.1Q tagging. They connect switches to switches or switches to routers.',
        },
      ],
    },
    {
      'order': 6,
      'title': 'Routing Fundamentals',
      'subtitle': 'Static routing, dynamic routing, and how routers work',
      'status': 'locked',
      'content': '''
# Routing Fundamentals

Routing is the process of forwarding packets between different networks. Routers operate at **Layer 3** and make decisions based on **IP addresses** using routing tables.

## How Routers Work
1. A packet arrives at the router's interface
2. The router reads the destination IP address
3. It looks up the best match in the **routing table**
4. It forwards the packet out the appropriate interface

### Routing Table
Contains entries for known networks with:
- **Destination network**
- **Subnet mask**
- **Next hop** (where to send the packet)
- **Interface** (which port to use)
- **Metric** (cost of the route)

## Types of Routes

### Directly Connected Routes
Added automatically when an interface is configured with an IP address and is active.

### Static Routes
Manually configured by an administrator.
- **Advantages:** Predictable, secure, low overhead
- **Disadvantages:** No automatic failover, doesn't scale

**Default Route (0.0.0.0/0):** A static route that matches any destination — used as a "last resort" when no specific route exists. Also called the **gateway of last resort**.

### Dynamic Routing
Routers automatically discover and share routes using routing protocols.

## Routing Protocols

### Distance Vector Protocols
Routers share their entire routing table with neighbors periodically.
- **RIP (Routing Information Protocol):** Uses hop count as metric. Max 15 hops. Slow convergence.
- **EIGRP (Enhanced Interior Gateway Routing Protocol):** Cisco proprietary. Uses bandwidth and delay. Fast convergence.

### Link State Protocols
Routers share information about their directly connected links. Each router builds a complete map of the network.
- **OSPF (Open Shortest Path First):** Open standard. Uses cost (based on bandwidth). Scales well.
- **IS-IS:** Used by ISPs. Similar to OSPF.

### Path Vector Protocols
- **BGP (Border Gateway Protocol):** The routing protocol of the internet. Used between autonomous systems (AS). Highly scalable and policy-based.

## Administrative Distance (AD)
When multiple routing sources provide a route to the same destination, the router uses **AD** to pick the most trustworthy source.

| Source | AD |
|---|---|
| Directly connected | 0 |
| Static route | 1 |
| EIGRP | 90 |
| OSPF | 110 |
| RIP | 120 |
| Unknown | 255 |

Lower AD = more trusted.

## NAT (Network Address Translation)
NAT translates private IP addresses to public IP addresses, allowing multiple devices to share one public IP.
- **Static NAT:** One-to-one mapping
- **Dynamic NAT:** Pool of public IPs mapped dynamically
- **PAT (Port Address Translation):** Many-to-one using port numbers (most common, also called NAT overload)
''',
      'quizQuestions': [
        {
          'question': 'What is the default route also known as?',
          'options': [
            'Default gateway',
            'Last resort gateway',
            'Gateway of last resort',
            'Fallback route',
          ],
          'correctIndex': 2,
          'explanation':
              'The default route (0.0.0.0/0) is also called the gateway of last resort. It matches any destination when no more specific route exists.',
        },
        {
          'question': 'Which routing protocol uses hop count as its metric?',
          'options': ['OSPF', 'EIGRP', 'BGP', 'RIP'],
          'correctIndex': 3,
          'explanation':
              'RIP uses hop count as its metric with a maximum of 15 hops. A hop count of 16 is considered unreachable.',
        },
        {
          'question':
              'Which has the lowest (most trusted) Administrative Distance?',
          'options': ['Static route', 'OSPF', 'Directly connected', 'EIGRP'],
          'correctIndex': 2,
          'explanation':
              'Directly connected routes have an AD of 0, making them the most trusted. The router knows these networks are directly reachable.',
        },
        {
          'question':
              'What type of NAT allows many private IPs to share one public IP using port numbers?',
          'options': ['Static NAT', 'Dynamic NAT', 'PAT', 'Reverse NAT'],
          'correctIndex': 2,
          'explanation':
              'PAT (Port Address Translation), also called NAT overload, uses port numbers to allow multiple devices to share a single public IP address.',
        },
        {
          'question':
              'Which routing protocol is used between autonomous systems on the internet?',
          'options': ['OSPF', 'RIP', 'EIGRP', 'BGP'],
          'correctIndex': 3,
          'explanation':
              'BGP (Border Gateway Protocol) is the routing protocol of the internet, used to exchange routing information between autonomous systems.',
        },
      ],
    },
    {
      'order': 7,
      'title': 'Network Security Fundamentals',
      'subtitle': 'Firewalls, ACLs, VPNs, and basic security concepts',
      'status': 'locked',
      'content': '''
# Network Security Fundamentals

Network security protects the infrastructure, data, and resources from unauthorized access, misuse, and attacks. As a network professional, security is inseparable from your role.

## Defense in Depth
A layered security approach — no single control is relied upon. Multiple overlapping defenses reduce risk.

## Firewalls
A firewall controls traffic entering and leaving a network based on rules.

### Types of Firewalls
- **Packet Filtering:** Inspects individual packets based on source/destination IP, port, protocol. Stateless.
- **Stateful Inspection:** Tracks the state of connections. Allows return traffic for established connections automatically.
- **Application Layer (Next-Gen):** Inspects traffic up to Layer 7. Can identify applications regardless of port.
- **Proxy Firewall:** Acts as an intermediary. Breaks the direct connection between source and destination.

### Firewall Zones
- **Inside (Trusted):** Internal network
- **Outside (Untrusted):** Internet
- **DMZ (Demilitarized Zone):** Semi-trusted zone for public-facing servers (web, email, DNS)

## ACLs (Access Control Lists)
Rules applied to router interfaces that permit or deny traffic based on IP addresses, protocols, and ports.

- **Standard ACL:** Filters based on source IP only. Applied close to destination.
- **Extended ACL:** Filters on source IP, destination IP, protocol, and port. Applied close to source.

## VPNs (Virtual Private Networks)
Create encrypted tunnels over untrusted networks (like the internet).

### VPN Types
- **Site-to-Site VPN:** Connects two networks permanently (e.g., branch office to HQ)
- **Remote Access VPN:** Individual users connect to a network remotely (e.g., work from home)
- **SSL VPN:** Uses HTTPS. No client software needed. Browser-based.

### VPN Protocols
- **IPSec:** Industry standard. Uses AH and ESP. Works in tunnel or transport mode.
- **OpenVPN:** Open source, highly configurable.
- **WireGuard:** Modern, fast, simple.
- **L2TP/IPSec:** L2TP for tunneling, IPSec for encryption.

## IDS vs IPS
- **IDS (Intrusion Detection System):** Monitors and alerts on suspicious activity. Passive — does not block.
- **IPS (Intrusion Prevention System):** Monitors and actively blocks threats. Inline device.

## Common Network Attacks
- **DoS/DDoS:** Overwhelm a system with traffic to make it unavailable
- **Man-in-the-Middle (MitM):** Attacker intercepts communications between two parties
- **ARP Spoofing:** Sends fake ARP replies to associate attacker's MAC with a legitimate IP
- **MAC Flooding:** Fills a switch's CAM table, forcing it to broadcast all traffic
- **VLAN Hopping:** Attacker gains access to traffic on other VLANs
- **DNS Spoofing:** Returns false DNS responses to redirect traffic

## Network Hardening
- Disable unused ports and services
- Use strong authentication (MFA)
- Segment the network with VLANs
- Keep firmware and software updated
- Use encrypted management protocols (SSH, HTTPS, SNMPv3)
- Implement 802.1X port authentication
''',
      'quizQuestions': [
        {
          'question': 'What is a DMZ in network security?',
          'options': [
            'A type of VPN',
            'A semi-trusted zone for public-facing servers',
            'An encrypted tunnel',
            'A firewall rule set',
          ],
          'correctIndex': 1,
          'explanation':
              'A DMZ (Demilitarized Zone) is a network segment that sits between the trusted internal network and the untrusted internet, hosting public-facing servers.',
        },
        {
          'question':
              'Which type of ACL can filter based on both source and destination IP?',
          'options': [
            'Standard ACL',
            'Extended ACL',
            'Named ACL',
            'Dynamic ACL',
          ],
          'correctIndex': 1,
          'explanation':
              'Extended ACLs can filter on source IP, destination IP, protocol, and port numbers — making them much more flexible than standard ACLs.',
        },
        {
          'question': 'What is the key difference between IDS and IPS?',
          'options': [
            'IDS uses hardware, IPS uses software',
            'IDS is active, IPS is passive',
            'IDS only detects, IPS actively blocks',
            'IDS works at Layer 3, IPS at Layer 7',
          ],
          'correctIndex': 2,
          'explanation':
              'IDS (Intrusion Detection System) passively monitors and alerts. IPS (Intrusion Prevention System) is inline and actively blocks detected threats.',
        },
        {
          'question':
              'Which VPN type is best for connecting a branch office to headquarters?',
          'options': [
            'Remote Access VPN',
            'SSL VPN',
            'Site-to-Site VPN',
            'Split Tunnel VPN',
          ],
          'correctIndex': 2,
          'explanation':
              'Site-to-Site VPN creates a permanent encrypted tunnel between two networks, making it ideal for connecting branch offices to headquarters.',
        },
        {
          'question':
              'What attack overwhelms a target with traffic to make it unavailable?',
          'options': ['MitM', 'ARP Spoofing', 'VLAN Hopping', 'DDoS'],
          'correctIndex': 3,
          'explanation':
              'A DDoS (Distributed Denial of Service) attack uses multiple sources to flood a target with traffic, making it unavailable to legitimate users.',
        },
      ],
    },
    {
      'order': 8,
      'title': 'Wireless Networking',
      'subtitle': 'Wi-Fi standards, security, and enterprise wireless',
      'status': 'locked',
      'content': '''
# Wireless Networking

Wireless networking has become the primary way devices connect to networks. Understanding Wi-Fi standards, security, and design is essential for modern network professionals.

## IEEE 802.11 Standards

| Standard | Frequency | Max Speed | Range | Notes |
|---|---|---|---|---|
| 802.11a | 5 GHz | 54 Mbps | Short | Early, less interference |
| 802.11b | 2.4 GHz | 11 Mbps | Long | First widely adopted |
| 802.11g | 2.4 GHz | 54 Mbps | Long | Backward compatible with b |
| 802.11n (Wi-Fi 4) | 2.4/5 GHz | 600 Mbps | Long | MIMO introduced |
| 802.11ac (Wi-Fi 5) | 5 GHz | 3.5 Gbps | Medium | MU-MIMO, beamforming |
| 802.11ax (Wi-Fi 6) | 2.4/5/6 GHz | 9.6 Gbps | Good | OFDMA, better in dense environments |

## Frequency Bands
- **2.4 GHz:** Longer range, more interference (microwaves, Bluetooth), fewer channels
- **5 GHz:** Shorter range, less interference, more channels, faster
- **6 GHz (Wi-Fi 6E):** New band, very fast, short range

### Non-Overlapping Channels (2.4 GHz)
Only channels **1, 6, and 11** are non-overlapping in the 2.4 GHz band. Using overlapping channels causes interference.

## Wireless Security

### Security Protocols (Oldest to Newest)
- **WEP (Wired Equivalent Privacy):** Broken, do not use. RC4 cipher with weak implementation.
- **WPA (Wi-Fi Protected Access):** Temporary fix for WEP. TKIP cipher. Still weak.
- **WPA2:** Strong. Uses AES-CCMP encryption. Current standard.
- **WPA3:** Latest. Stronger encryption, protects against offline dictionary attacks, forward secrecy.

### Authentication Modes
- **Personal (PSK):** Pre-shared key. One password for all users. Home/small office.
- **Enterprise (802.1X):** Each user authenticates individually with credentials via a RADIUS server. Corporate environments.

## Wireless Threats
- **Evil Twin:** Rogue AP mimicking a legitimate one to capture traffic
- **Deauthentication Attack:** Forces clients to disconnect (used in cracking attempts)
- **War Driving:** Driving around scanning for open/weak wireless networks
- **Eavesdropping:** Capturing unencrypted wireless traffic

## Enterprise Wireless Architecture

### Autonomous APs
Each AP configured independently. Suitable for small deployments.

### Controller-Based (Centralized)
A **Wireless LAN Controller (WLC)** manages all APs centrally.
- Easier management
- Roaming between APs without drops
- Centralized security policies

### Cloud-Managed
APs managed through cloud dashboard (e.g., Cisco Meraki, Ubiquiti UniFi). No physical controller needed.

## SSID and Roaming
- **SSID (Service Set Identifier):** The network name broadcast by an AP
- **BSS (Basic Service Set):** Single AP + its clients
- **ESS (Extended Service Set):** Multiple APs sharing the same SSID — allows seamless roaming
''',
      'quizQuestions': [
        {
          'question':
              'Which Wi-Fi standard introduced OFDMA and performs best in dense environments?',
          'options': [
            '802.11ac (Wi-Fi 5)',
            '802.11n (Wi-Fi 4)',
            '802.11ax (Wi-Fi 6)',
            '802.11a',
          ],
          'correctIndex': 2,
          'explanation':
              '802.11ax (Wi-Fi 6) introduced OFDMA which allows multiple users to be served simultaneously, making it much more efficient in dense environments.',
        },
        {
          'question':
              'Which wireless security protocol should never be used due to known vulnerabilities?',
          'options': ['WPA2', 'WPA3', 'WEP', 'WPA'],
          'correctIndex': 2,
          'explanation':
              'WEP (Wired Equivalent Privacy) is completely broken and should never be used. It can be cracked in minutes with freely available tools.',
        },
        {
          'question':
              'What are the non-overlapping channels in the 2.4 GHz band?',
          'options': ['1, 4, 7', '1, 6, 11', '2, 6, 10', '1, 5, 9'],
          'correctIndex': 1,
          'explanation':
              'In the 2.4 GHz band, only channels 1, 6, and 11 are non-overlapping. Using overlapping channels causes co-channel interference.',
        },
        {
          'question': 'What is an Evil Twin attack?',
          'options': [
            'Cloning a MAC address',
            'A rogue AP mimicking a legitimate network',
            'Forcing clients to disconnect',
            'Cracking WPA2 passwords',
          ],
          'correctIndex': 1,
          'explanation':
              'An Evil Twin is a rogue access point that impersonates a legitimate network to trick users into connecting, allowing the attacker to intercept traffic.',
        },
        {
          'question': 'What does WLC stand for in enterprise wireless?',
          'options': [
            'Wireless LAN Controller',
            'Wide Layer Connection',
            'Wireless Link Channel',
            'Wired LAN Concentrator',
          ],
          'correctIndex': 0,
          'explanation':
              'WLC stands for Wireless LAN Controller — a centralized device that manages multiple access points in an enterprise wireless deployment.',
        },
      ],
    },
    {
      'order': 9,
      'title': 'DNS, DHCP & Network Services',
      'subtitle': 'Core infrastructure services every network depends on',
      'status': 'locked',
      'content': '''
# DNS, DHCP & Network Services

These services are the invisible backbone of every network. Without them, users would need to memorize IP addresses and configure every device manually.

## DNS (Domain Name System)

DNS translates human-readable domain names into IP addresses.

### DNS Resolution Process
1. User types **www.example.com** in browser
2. Browser checks **local cache**
3. If not cached, queries **local DNS resolver** (usually the ISP or internal DNS server)
4. Resolver checks its own cache
5. If not cached, queries **Root Name Server** (13 sets worldwide)
6. Root server refers to **TLD Name Server** (.com, .org, .net)
7. TLD server refers to **Authoritative Name Server** for the domain
8. Authoritative server returns the IP address
9. Resolver caches the result and returns it to the client

### DNS Record Types
| Record | Purpose |
|---|---|
| A | Maps hostname to IPv4 address |
| AAAA | Maps hostname to IPv6 address |
| CNAME | Alias pointing to another hostname |
| MX | Mail exchange server for a domain |
| NS | Authoritative name servers for a domain |
| PTR | Reverse lookup — IP to hostname |
| TXT | Text records (used for SPF, DKIM, domain verification) |
| SOA | Start of Authority — info about the zone |
| SRV | Service location records |

### DNS Security
- **DNSSEC:** Digitally signs DNS records to prevent spoofing
- **DNS over HTTPS (DoH):** Encrypts DNS queries
- **DNS over TLS (DoT):** Encrypts DNS using TLS

## DHCP (Dynamic Host Configuration Protocol)

DHCP automatically assigns IP configuration to devices on a network.

### What DHCP Assigns
- IP address
- Subnet mask
- Default gateway
- DNS server addresses
- Lease time

### DHCP DORA Process
1. **Discover:** Client broadcasts to find a DHCP server
2. **Offer:** Server offers an IP address
3. **Request:** Client requests the offered IP
4. **Acknowledge:** Server confirms and assigns the IP

### DHCP Options
- **Scope:** Range of IP addresses available for assignment
- **Exclusions:** IPs within the scope not assigned by DHCP
- **Reservations:** A specific IP always assigned to a specific MAC address
- **Lease Time:** How long an IP is assigned before it must be renewed

### DHCP Relay Agent
When a DHCP server is on a different subnet, a **DHCP relay agent** (usually a router) forwards DHCP broadcasts to the server.

## NTP (Network Time Protocol)
Synchronizes clocks across network devices. Critical for:
- Log correlation during incidents
- Certificate validity
- Kerberos authentication (requires clocks within 5 minutes)

Uses **UDP port 123**. Operates in a hierarchy called **stratum levels** — Stratum 0 is atomic clocks, Stratum 1 syncs from Stratum 0, etc.

## SNMP (Simple Network Management Protocol)
Used to monitor and manage network devices.
- **SNMPv1/v2:** Weak security (community strings in plaintext)
- **SNMPv3:** Encryption and authentication — always use this
- Uses **UDP ports 161 (agent) and 162 (trap)**

### Key SNMP Components
- **Manager:** The monitoring system
- **Agent:** Software on the managed device
- **MIB (Management Information Base):** Database of manageable objects
- **Trap:** Unsolicited alert from agent to manager
''',
      'quizQuestions': [
        {
          'question': 'What is the correct order of the DHCP process?',
          'options': ['DORA', 'ROAD', 'DARO', 'ODRA'],
          'correctIndex': 0,
          'explanation':
              'DORA: Discover, Offer, Request, Acknowledge — the four steps of the DHCP lease process.',
        },
        {
          'question':
              'Which DNS record type maps a hostname to an IPv4 address?',
          'options': ['AAAA', 'MX', 'A', 'CNAME'],
          'correctIndex': 2,
          'explanation':
              'An A record maps a hostname to an IPv4 address. AAAA records do the same for IPv6 addresses.',
        },
        {
          'question': 'What port does NTP use?',
          'options': ['53', '123', '161', '67'],
          'correctIndex': 1,
          'explanation':
              'NTP uses UDP port 123 to synchronize clocks across network devices.',
        },
        {
          'question':
              'Which version of SNMP provides encryption and authentication?',
          'options': ['SNMPv1', 'SNMPv2c', 'SNMPv2u', 'SNMPv3'],
          'correctIndex': 3,
          'explanation':
              'SNMPv3 added authentication and encryption to SNMP. Earlier versions transmitted community strings in plaintext, making them insecure.',
        },
        {
          'question': 'What device forwards DHCP broadcasts across subnets?',
          'options': [
            'DHCP proxy',
            'DHCP relay agent',
            'DHCP helper',
            'DHCP bridge',
          ],
          'correctIndex': 1,
          'explanation':
              'A DHCP relay agent (typically a router) forwards DHCP broadcast messages to a DHCP server on a different subnet.',
        },
      ],
    },
    {
      'order': 10,
      'title': 'Wide Area Networks (WAN)',
      'subtitle': 'WAN technologies, SD-WAN, and connectivity options',
      'status': 'locked',
      'content': '''
# Wide Area Networks (WAN)

WANs connect geographically separated networks — offices, data centers, and cloud environments. Choosing the right WAN technology affects cost, performance, and reliability.

## Traditional WAN Technologies

### Leased Lines
Dedicated point-to-point connections with guaranteed bandwidth. Expensive but reliable.
- **T1:** 1.544 Mbps
- **T3:** 44.736 Mbps
- **E1 (Europe):** 2.048 Mbps

### MPLS (Multiprotocol Label Switching)
Routes traffic using labels instead of IP addresses. Fast, reliable, supports QoS. Used by enterprises and carriers.
- Traffic is prioritized using labels
- Supports multiple protocols
- Provider-managed, expensive

### Frame Relay
Legacy packet-switched technology. Uses **PVCs (Permanent Virtual Circuits)**. Mostly obsolete.

### ATM (Asynchronous Transfer Mode)
Legacy. Uses fixed 53-byte cells. Very low latency. Used in carrier backbones. Largely replaced.

## Modern WAN Technologies

### Broadband Internet
DSL, Cable, Fiber — cost-effective but shared, variable quality.

### Metro Ethernet
Ethernet service over a carrier network. Scalable, familiar technology, good speeds.

### 4G/5G
Cellular WAN. Used as backup links or primary for remote sites. 5G offers very high speeds.

## SD-WAN (Software-Defined WAN)

SD-WAN decouples the WAN networking hardware from its control mechanism, using software to manage and optimize WAN connections.

### Key Benefits
- Use multiple WAN links (MPLS + internet + LTE) simultaneously
- Intelligent path selection based on application requirements
- Centralized management
- Lower cost than pure MPLS
- Encrypted tunnels over internet links

### How It Works
An SD-WAN controller monitors all WAN links and steers traffic based on policies:
- Critical apps (VoIP, video) → best quality link
- Bulk transfers → cheapest link
- Automatic failover if a link degrades

## VPN over WAN
For smaller organizations, **IPSec VPNs** over the internet can replace expensive MPLS — SD-WAN often manages these automatically.

## WAN Optimization
Techniques to improve performance over slow or high-latency WAN links:
- **Compression:** Reduces data size
- **Deduplication:** Avoids sending the same data twice
- **Caching:** Stores frequently accessed data locally
- **QoS:** Prioritizes critical traffic
- **TCP optimization:** Improves TCP behavior over high-latency links

## Last Mile Technologies
The connection from the provider's network to the customer premises:
- **DSL (Digital Subscriber Line):** Over phone lines. ADSL (asymmetric) is most common.
- **Cable:** Over coaxial cable. Shared medium.
- **Fiber (FTTH/FTTP):** Fiber to the home/premises. Fastest and most reliable.
- **Fixed Wireless:** Microwave or mmWave radio. Used in areas without wired infrastructure.
- **Satellite:** High latency. Used in very remote areas. LEO satellites (Starlink) have much lower latency.
''',
      'quizQuestions': [
        {
          'question':
              'What does MPLS use instead of IP addresses to forward traffic?',
          'options': ['MAC addresses', 'Port numbers', 'Labels', 'VLANs'],
          'correctIndex': 2,
          'explanation':
              'MPLS (Multiprotocol Label Switching) uses labels attached to packets to make fast forwarding decisions instead of looking up IP addresses.',
        },
        {
          'question':
              'What is the main advantage of SD-WAN over traditional MPLS?',
          'options': [
            'Higher latency',
            'Use of multiple WAN links with intelligent routing at lower cost',
            'No encryption needed',
            'Only works with fiber',
          ],
          'correctIndex': 1,
          'explanation':
              'SD-WAN can use multiple cheaper WAN links (internet, LTE) simultaneously with intelligent traffic steering, reducing dependency on expensive MPLS.',
        },
        {
          'question': 'What is the bandwidth of a T1 line?',
          'options': ['512 Kbps', '1.544 Mbps', '44.736 Mbps', '100 Mbps'],
          'correctIndex': 1,
          'explanation':
              'A T1 line provides 1.544 Mbps of bandwidth. It was the standard dedicated leased line for many years.',
        },
        {
          'question':
              'Which last-mile technology provides the highest speed and reliability?',
          'options': ['DSL', 'Cable', 'Satellite', 'Fiber (FTTH)'],
          'correctIndex': 3,
          'explanation':
              'Fiber to the home (FTTH) provides the highest speeds and most reliable connection as it uses fiber optic cables all the way to the premises.',
        },
        {
          'question':
              'What WAN optimization technique stores frequently accessed data locally?',
          'options': ['Compression', 'Deduplication', 'Caching', 'QoS'],
          'correctIndex': 2,
          'explanation':
              'Caching stores frequently accessed content locally so it does not need to be retrieved over the slow WAN link repeatedly.',
        },
      ],
    },
    {
      'order': 11,
      'title': 'Network Troubleshooting',
      'subtitle': 'Methodology, tools, and common issues',
      'status': 'locked',
      'content': '''
# Network Troubleshooting

Systematic troubleshooting is one of the most valuable skills a network professional can have. A structured approach saves time and reduces errors.

## Troubleshooting Methodology

### 7-Step Process
1. **Identify the problem** — gather symptoms, ask users, check logs
2. **Establish a theory of probable cause** — consider common causes first
3. **Test the theory** — verify if your theory is correct
4. **Establish a plan of action** — determine steps to resolve
5. **Implement the solution**
6. **Verify full system functionality**
7. **Document findings and lessons learned**

### Top-Down vs Bottom-Up vs Divide and Conquer
- **Top-Down:** Start at Application layer (Layer 7), work down
- **Bottom-Up:** Start at Physical layer (Layer 1), work up
- **Divide and Conquer:** Start at a middle layer (often Layer 3), test up and down

## Key Troubleshooting Tools

### ping
Tests basic IP connectivity using ICMP. If ping fails, the issue is Layer 3 or below.
```
ping 8.8.8.8
ping google.com
```

### traceroute / tracert
Shows the path packets take and where delays or failures occur.
```
traceroute 8.8.8.8 (Linux/Mac)
tracert 8.8.8.8 (Windows)
```

### ipconfig / ifconfig / ip
Shows IP configuration of network interfaces.
```
ipconfig /all (Windows)
ip addr show (Linux)
```

### nslookup / dig
Tests DNS resolution.
```
nslookup google.com
dig google.com
```

### netstat
Shows active connections, listening ports, routing table.

### arp -a
Displays the ARP cache (IP to MAC mappings).

### Wireshark / tcpdump
Packet capture and analysis. Can see exactly what traffic is on the network.

### nmap
Network scanner — discovers hosts and open ports.

## Common Network Issues

### No Connectivity
- Check physical connection (cable, lights on NIC/switch port)
- Check IP configuration (DHCP vs static, correct subnet)
- Ping default gateway — if it fails, issue is local
- Ping external IP — if it fails but gateway works, check routing/NAT
- Ping DNS server — if DNS resolution fails, check DNS config

### Slow Network
- Check for bandwidth saturation (interface errors, high utilization)
- Check for duplex mismatch (one side auto-negotiated wrong)
- Check for routing loops
- Run Wireshark to look for retransmissions or unusual traffic

### Intermittent Connectivity
- Physical layer issues (bad cable, loose connector)
- STP topology changes
- DHCP scope exhaustion (IPs running out)
- Wireless interference or roaming issues

### DNS Issues
- Can ping IP but not hostname → DNS problem
- Check DNS server setting on client
- Run nslookup to test DNS directly

### Duplex Mismatch
One device set to full-duplex, the other to half-duplex. Causes collisions and poor performance. Always set both sides to auto-negotiate or manually set both to full-duplex.
''',
      'quizQuestions': [
        {
          'question':
              'If you can ping an IP address but not a hostname, what is the likely issue?',
          'options': [
            'Physical layer problem',
            'Routing problem',
            'DNS problem',
            'Firewall blocking ping',
          ],
          'correctIndex': 2,
          'explanation':
              'If you can ping an IP but not resolve a hostname, the network connectivity is fine but DNS resolution is failing. Check DNS settings.',
        },
        {
          'question':
              'What command shows the path packets take to reach a destination?',
          'options': ['ping', 'netstat', 'traceroute', 'arp'],
          'correctIndex': 2,
          'explanation':
              'Traceroute (tracert on Windows) shows each hop a packet takes and the latency at each hop, helping identify where delays or failures occur.',
        },
        {
          'question':
              'Which troubleshooting approach starts at the Physical layer?',
          'options': [
            'Top-Down',
            'Bottom-Up',
            'Divide and Conquer',
            'Inside-Out',
          ],
          'correctIndex': 1,
          'explanation':
              'Bottom-Up troubleshooting starts at Layer 1 (Physical) and works up through the layers. Good when physical issues are suspected.',
        },
        {
          'question': 'What tool captures and analyzes network packets?',
          'options': ['nmap', 'netstat', 'Wireshark', 'nslookup'],
          'correctIndex': 2,
          'explanation':
              'Wireshark is a network protocol analyzer that captures packets in real time and allows detailed analysis of network traffic.',
        },
        {
          'question': 'What causes a duplex mismatch?',
          'options': [
            'Wrong VLAN assignment',
            'One device using full-duplex, the other half-duplex',
            'IP address conflict',
            'Wrong subnet mask',
          ],
          'correctIndex': 1,
          'explanation':
              'A duplex mismatch occurs when one device is set to full-duplex and the other to half-duplex, causing collisions and degraded performance.',
        },
      ],
    },
    {
      'order': 12,
      'title': 'Network Cabling & Physical Layer',
      'subtitle': 'Copper, fiber, and physical infrastructure',
      'status': 'locked',
      'content': '''
# Network Cabling & Physical Layer

The physical layer is the foundation of every network. No matter how sophisticated the software, it all depends on reliable physical connections.

## Copper Cabling

### Twisted Pair (UTP/STP)
The most common LAN cable. Pairs of copper wires twisted together to reduce interference.

| Category | Speed | Max Distance | Use |
|---|---|---|---|
| Cat5 | 100 Mbps | 100m | Legacy |
| Cat5e | 1 Gbps | 100m | Common |
| Cat6 | 1-10 Gbps | 55m (10G) / 100m (1G) | Standard |
| Cat6a | 10 Gbps | 100m | Data centers |
| Cat7 | 10 Gbps | 100m | Shielded, data centers |
| Cat8 | 25-40 Gbps | 30m | Data centers |

- **UTP (Unshielded Twisted Pair):** No shielding. Most common. Vulnerable to EMI.
- **STP (Shielded Twisted Pair):** Has shielding. Used in high-EMI environments.

### Coaxial Cable
Center copper conductor surrounded by insulation, metal shield, and outer jacket. Used for cable TV and broadband internet.

### Straight-Through vs Crossover Cables
- **Straight-Through:** Same wiring on both ends. Used to connect different device types (PC to switch).
- **Crossover:** Reversed TX/RX pairs. Used to connect same device types (switch to switch). Mostly obsolete with modern auto-MDI/X.

## Fiber Optic Cabling
Transmits data as light pulses through glass or plastic fibers. Immune to EMI, secure, long distances.

### Single-Mode Fiber (SMF)
- Narrow core (8-10 microns)
- Carries one light mode
- Very long distances (up to 100km+)
- Yellow jacket typically
- Used in WANs, campus backbones

### Multi-Mode Fiber (MMF)
- Wider core (50-62.5 microns)
- Multiple light modes
- Shorter distances (up to 2km)
- Orange or aqua jacket typically
- Used in data centers, short building runs

### Fiber Connectors
- **LC:** Small form factor, most common in data centers
- **SC:** Square connector, common in telco
- **ST:** Bayonet-style, legacy
- **MPO/MTP:** Multi-fiber, used for high-density connections

## Cable Management & Standards
- **TIA/EIA 568:** Defines structured cabling standards
- **T568A / T568B:** Two wiring schemes for RJ-45 connectors. T568B is most common in North America.
- **Patch panel:** Central termination point for horizontal cabling
- **IDF (Intermediate Distribution Frame):** Floor-level wiring closet
- **MDF (Main Distribution Frame):** Central wiring room

## PoE (Power over Ethernet)
Delivers electrical power over Ethernet cables. Eliminates need for separate power supply.
- **PoE (802.3af):** Up to 15.4W
- **PoE+ (802.3at):** Up to 30W
- **PoE++ (802.3bt):** Up to 60-100W
- Used for: IP phones, wireless APs, IP cameras, IoT devices
''',
      'quizQuestions': [
        {
          'question': 'Which cable category supports 10 Gbps up to 100 meters?',
          'options': ['Cat5e', 'Cat6', 'Cat6a', 'Cat7'],
          'correctIndex': 2,
          'explanation':
              'Cat6a supports 10 Gbps up to 100 meters. Regular Cat6 only supports 10 Gbps up to 55 meters.',
        },
        {
          'question':
              'What is the key advantage of single-mode fiber over multi-mode?',
          'options': [
            'Cheaper cost',
            'Easier to terminate',
            'Much longer transmission distances',
            'Higher bandwidth in data centers',
          ],
          'correctIndex': 2,
          'explanation':
              'Single-mode fiber supports much longer distances (100km+) compared to multi-mode (up to 2km) because it carries only one light mode with less signal degradation.',
        },
        {
          'question':
              'What wiring standard is most common for RJ-45 connectors in North America?',
          'options': ['T568A', 'T568B', 'T568C', 'EIA-232'],
          'correctIndex': 1,
          'explanation':
              'T568B is the most commonly used wiring standard for RJ-45 connectors in North America, though T568A is also acceptable.',
        },
        {
          'question': 'What does PoE+ (802.3at) deliver up to?',
          'options': ['15.4W', '30W', '60W', '100W'],
          'correctIndex': 1,
          'explanation':
              'PoE+ (802.3at) delivers up to 30W of power over Ethernet cable. Standard PoE (802.3af) delivers up to 15.4W.',
        },
        {
          'question':
              'Which fiber connector is most common in modern data centers?',
          'options': ['ST', 'SC', 'LC', 'FC'],
          'correctIndex': 2,
          'explanation':
              'LC (Lucent Connector) is the most common fiber connector in modern data centers due to its small form factor and high density.',
        },
      ],
    },
    {
      'order': 13,
      'title': 'Network Design & Architecture',
      'subtitle': 'Hierarchical design, redundancy, and scalability',
      'status': 'locked',
      'content': '''
# Network Design & Architecture

Good network design is about more than connecting devices — it's about building infrastructure that is reliable, scalable, secure, and maintainable.

## Hierarchical Network Design

The **three-layer hierarchical model** is the foundation of enterprise network design.

### Core Layer
- **Purpose:** Fast backbone, high-speed switching between distribution blocks
- **Focus:** Speed and reliability, NOT security or access control
- **Characteristics:** Redundant, no access control lists, minimal packet manipulation
- **Devices:** High-performance core switches/routers

### Distribution Layer
- **Purpose:** Aggregates access layer connections, policy enforcement
- **Focus:** Routing, filtering, QoS, summarization
- **Characteristics:** Connects access layer to core, enforces security policies
- **Devices:** Layer 3 switches, routers

### Access Layer
- **Purpose:** End-user connectivity
- **Focus:** Port security, VLANs, PoE
- **Characteristics:** Connects users and devices to the network
- **Devices:** Layer 2 switches

## Spine-Leaf Architecture
Modern data center design replacing traditional three-tier:
- **Spine switches:** Core, every leaf connects to every spine
- **Leaf switches:** Access, connect servers and uplink to all spines
- **Benefits:** Consistent low latency, easy to scale, no STP needed

## High Availability & Redundancy

### HSRP (Hot Standby Router Protocol)
Cisco proprietary. Creates a virtual IP shared by two routers. If the active router fails, standby takes over transparently.

### VRRP (Virtual Router Redundancy Protocol)
Open standard version of HSRP.

### GLBP (Gateway Load Balancing Protocol)
Cisco proprietary. Like HSRP but also load balances across multiple routers.

### Link Aggregation (LACP / 802.3ad)
Bundles multiple physical links into one logical link for:
- **Increased bandwidth** (up to 8 links)
- **Redundancy** (if one link fails, others continue)

## Network Documentation
Essential for troubleshooting, planning, and compliance:
- **Physical diagrams:** Actual cable connections and physical locations
- **Logical diagrams:** IP addressing, VLANs, routing
- **Rack diagrams:** Equipment placement in racks
- **IP address management (IPAM):** Tracks IP allocations

## Capacity Planning
Anticipating future growth:
- **Baseline:** Document current utilization
- **Growth rate:** Estimate traffic growth
- **Headroom:** Design for 50-70% average utilization max
- **Scalability:** Choose equipment that can expand

## QoS (Quality of Service)
Prioritizes certain types of traffic to ensure performance:
- **Classification:** Identify and mark traffic
- **Queuing:** Different queues for different priorities
- **Shaping/Policing:** Control traffic rates
- **DSCP (Differentiated Services Code Point):** Marking system for QoS
- Voice traffic typically given **highest priority (EF - Expedited Forwarding)**
''',
      'quizQuestions': [
        {
          'question':
              'In the three-layer hierarchical model, which layer connects end users to the network?',
          'options': ['Core', 'Distribution', 'Access', 'Edge'],
          'correctIndex': 2,
          'explanation':
              'The Access layer is where end users and devices connect to the network. It handles port security, VLANs, and PoE.',
        },
        {
          'question': 'What does HSRP provide?',
          'options': [
            'Link aggregation',
            'VLAN segmentation',
            'Default gateway redundancy',
            'Wireless roaming',
          ],
          'correctIndex': 2,
          'explanation':
              'HSRP (Hot Standby Router Protocol) provides default gateway redundancy by using a virtual IP shared between two routers.',
        },
        {
          'question': 'What is the main advantage of Spine-Leaf architecture?',
          'options': [
            'Lower cost',
            'Uses STP for redundancy',
            'Consistent low latency and easy scaling',
            'Better wireless coverage',
          ],
          'correctIndex': 2,
          'explanation':
              'Spine-Leaf provides consistent, predictable low latency because any server is only ever two hops away, and it scales easily by adding leaf or spine switches.',
        },
        {
          'question': 'What does LACP provide?',
          'options': [
            'Gateway redundancy',
            'Link aggregation for bandwidth and redundancy',
            'VLAN tagging',
            'IP address assignment',
          ],
          'correctIndex': 1,
          'explanation':
              'LACP (Link Aggregation Control Protocol / 802.3ad) bundles multiple physical links into one logical link for increased bandwidth and redundancy.',
        },
        {
          'question':
              'Which QoS marking system uses values in packet headers to classify traffic?',
          'options': ['VLAN tags', '802.1Q', 'DSCP', 'ACL'],
          'correctIndex': 2,
          'explanation':
              'DSCP (Differentiated Services Code Point) marks packets in the IP header to indicate their QoS priority, allowing network devices to treat them accordingly.',
        },
      ],
    },
    {
      'order': 14,
      'title': 'Cloud Networking',
      'subtitle': 'VPCs, hybrid cloud, and cloud connectivity',
      'status': 'locked',
      'content': '''
# Cloud Networking

Cloud networking has fundamentally changed how organizations design and operate their networks. Understanding how networking works in cloud environments is now a core skill.

## Cloud Networking Fundamentals

### VPC (Virtual Private Cloud)
A logically isolated section of a cloud provider's network where you deploy resources. Think of it as your own private data center in the cloud.

**Key Components:**
- **Subnets:** Divide VPC address space (public and private)
- **Route Tables:** Control traffic flow within and out of the VPC
- **Internet Gateway:** Allows public subnet resources to reach the internet
- **NAT Gateway:** Allows private subnet resources to initiate outbound internet connections
- **Security Groups:** Stateful virtual firewalls for instances
- **Network ACLs:** Stateless subnet-level firewall

### Cloud Connectivity Options

#### Internet (Public)
Traffic goes over the public internet. Cheap, but variable performance and less secure.

#### VPN (Site-to-Site)
Encrypted IPSec tunnel from on-premises to cloud. Good for smaller workloads.
- AWS: AWS VPN
- Azure: VPN Gateway
- GCP: Cloud VPN

#### Dedicated Connection
Private, dedicated link from on-premises directly to cloud provider. Higher cost but consistent performance and lower latency.
- AWS: **Direct Connect**
- Azure: **ExpressRoute**
- GCP: **Cloud Interconnect**

## Hybrid Cloud Networking
Connects on-premises infrastructure with public cloud environments.

**Considerations:**
- Latency requirements
- Bandwidth needs
- Security and compliance
- Cost

## Software-Defined Networking (SDN)
Separates the control plane from the data plane, enabling centralized, programmable network management.

- **Control Plane:** Makes decisions about where traffic goes (brain)
- **Data Plane:** Forwards traffic based on control plane decisions (muscle)
- **Management Plane:** Configuration and monitoring

**Benefits:**
- Centralized management
- Automation and programmability
- Faster provisioning
- Vendor-agnostic (using open APIs)

## Network Function Virtualization (NFV)
Replaces dedicated hardware appliances (firewalls, load balancers, routers) with software running on standard servers.
- **vFirewall:** Virtual firewall
- **vRouter:** Virtual router
- **vLB:** Virtual load balancer

**Benefits:** Lower cost, faster deployment, easier scaling

## Load Balancing
Distributes traffic across multiple servers to ensure availability and performance.

### Types
- **Layer 4 (Transport):** Routes based on IP and TCP/UDP ports
- **Layer 7 (Application):** Routes based on content (URL, cookies, headers)

### Algorithms
- **Round Robin:** Each server in turn
- **Least Connections:** Send to server with fewest active connections
- **IP Hash:** Same client always goes to same server
- **Weighted:** Servers with more capacity get more traffic

## DNS in the Cloud
Cloud DNS services are globally distributed and highly available:
- AWS: Route 53
- Azure: Azure DNS
- GCP: Cloud DNS

Features include geographic routing, latency-based routing, health checks, and failover.
''',
      'quizQuestions': [
        {
          'question':
              'What AWS service provides a dedicated private connection from on-premises to AWS?',
          'options': [
            'AWS VPN',
            'AWS Direct Connect',
            'AWS Transit Gateway',
            'AWS PrivateLink',
          ],
          'correctIndex': 1,
          'explanation':
              'AWS Direct Connect provides a dedicated physical connection from your on-premises network to AWS, bypassing the public internet.',
        },
        {
          'question':
              'In a VPC, what allows private subnet resources to initiate outbound internet connections?',
          'options': [
            'Internet Gateway',
            'Security Group',
            'NAT Gateway',
            'Route Table',
          ],
          'correctIndex': 2,
          'explanation':
              'A NAT Gateway allows resources in private subnets to initiate outbound connections to the internet while preventing inbound connections from the internet.',
        },
        {
          'question':
              'What does SDN separate to enable centralized network management?',
          'options': [
            'Hardware from software',
            'Control plane from data plane',
            'Physical from virtual',
            'LAN from WAN',
          ],
          'correctIndex': 1,
          'explanation':
              'SDN separates the control plane (decision-making) from the data plane (traffic forwarding), enabling centralized, programmable network management.',
        },
        {
          'question':
              'Which load balancing algorithm sends traffic to the server with the fewest active connections?',
          'options': [
            'Round Robin',
            'IP Hash',
            'Least Connections',
            'Weighted',
          ],
          'correctIndex': 2,
          'explanation':
              'Least Connections algorithm routes new requests to the server currently handling the fewest active connections, distributing load based on real-time capacity.',
        },
        {
          'question': 'What does NFV replace?',
          'options': [
            'Physical network cables',
            'IP addressing',
            'Dedicated hardware appliances with software',
            'Cloud providers',
          ],
          'correctIndex': 2,
          'explanation':
              'NFV (Network Function Virtualization) replaces dedicated hardware appliances like firewalls and routers with software running on standard servers.',
        },
      ],
    },
    {
      'order': 15,
      'title': 'Network Monitoring & Management',
      'subtitle': 'Monitoring tools, logging, and network management systems',
      'status': 'locked',
      'content': '''
# Network Monitoring & Management

You cannot manage what you cannot see. Proactive monitoring is essential for maintaining network health and responding quickly to issues.

## Why Monitor?
- Detect issues before users report them
- Establish performance baselines
- Capacity planning
- Security threat detection
- Compliance and auditing
- SLA verification

## Key Metrics to Monitor
- **Bandwidth utilization:** % of available capacity used
- **Latency:** Round-trip time for packets
- **Packet loss:** % of packets that don't arrive
- **Jitter:** Variation in latency (critical for VoIP)
- **Error rates:** Interface errors, collisions
- **CPU/Memory:** Device resource utilization
- **Uptime/Availability:** % of time device is reachable

## SNMP-Based Monitoring
Most network monitoring relies on SNMP to collect data from devices.

### Key Monitoring Tools
- **Nagios:** Open source, alert-based monitoring
- **Zabbix:** Open source, full-featured monitoring
- **PRTG:** Commercial, easy to use
- **SolarWinds:** Enterprise-grade, comprehensive
- **Cisco DNA Center:** Cisco's intent-based networking management
- **Datadog / Grafana:** Modern cloud-native monitoring

### Polling vs Traps
- **Polling:** Manager queries agents at regular intervals (active)
- **Traps:** Agent sends alert to manager when something happens (reactive)

## Syslog
Devices send log messages to a central **syslog server**.

### Syslog Severity Levels (0-7)
| Level | Name | Description |
|---|---|---|
| 0 | Emergency | System unusable |
| 1 | Alert | Immediate action needed |
| 2 | Critical | Critical condition |
| 3 | Error | Error condition |
| 4 | Warning | Warning condition |
| 5 | Notice | Normal but significant |
| 6 | Informational | Informational messages |
| 7 | Debug | Debug-level messages |

Uses **UDP port 514** (or TCP for reliable delivery).

## NetFlow / sFlow
Collects metadata about network flows (who talked to whom, how much data, which ports).
- **NetFlow:** Cisco standard. Detailed flow data.
- **sFlow:** Open standard. Uses sampling.
- **IPFIX:** Open standard based on NetFlow v9.

Used for: traffic analysis, security monitoring, capacity planning.

## Network Configuration Management
- **Version control for configs:** Store configs in Git
- **Backup:** Regularly back up device configurations
- **Change management:** Document and approve all changes
- **Automation:** Use tools like Ansible, Terraform, or Cisco NSO

## ITIL & Change Management
Following structured change management reduces outages:
1. **Request for Change (RFC)**
2. **Change Advisory Board (CAB) review**
3. **Approval**
4. **Implementation with rollback plan**
5. **Post-implementation review**

## Bandwidth Management
- **QoS:** Prioritize critical traffic
- **Traffic shaping:** Smooth out bursts
- **Traffic policing:** Drop/mark excess traffic
- **Bandwidth monitoring:** Identify top talkers
''',
      'quizQuestions': [
        {
          'question':
              'Which syslog severity level indicates the system is unusable?',
          'options': [
            'Level 1 - Alert',
            'Level 0 - Emergency',
            'Level 2 - Critical',
            'Level 3 - Error',
          ],
          'correctIndex': 1,
          'explanation':
              'Syslog Level 0 (Emergency) indicates the system is unusable and requires immediate attention. It is the most severe level.',
        },
        {
          'question': 'What does NetFlow collect?',
          'options': [
            'Packet content',
            'Metadata about network flows',
            'SNMP traps',
            'DNS queries',
          ],
          'correctIndex': 1,
          'explanation':
              'NetFlow collects metadata about network flows — source/destination IPs and ports, protocol, bytes transferred — without capturing actual packet contents.',
        },
        {
          'question': 'What port does syslog use by default?',
          'options': ['161', '162', '514', '123'],
          'correctIndex': 2,
          'explanation':
              'Syslog uses UDP port 514 by default. TCP 514 can also be used for reliable delivery.',
        },
        {
          'question': 'What is jitter and why does it matter?',
          'options': [
            'Packet loss — matters for file transfers',
            'Variation in latency — critical for VoIP',
            'High CPU on switches — causes slowdowns',
            'Duplicate packets — affects accuracy',
          ],
          'correctIndex': 1,
          'explanation':
              'Jitter is variation in packet latency. It is critical for VoIP and video because audio/video must arrive at consistent intervals to sound and look good.',
        },
        {
          'question': 'What is the difference between SNMP polling and traps?',
          'options': [
            'Polling uses UDP, traps use TCP',
            'Polling is active querying, traps are device-initiated alerts',
            'Polling is encrypted, traps are not',
            'There is no difference',
          ],
          'correctIndex': 1,
          'explanation':
              'Polling actively queries devices at regular intervals. Traps are unsolicited alerts sent by devices when specific events occur, enabling faster response.',
        },
      ],
    },
    {
      'order': 16,
      'title': 'IPv6 Deep Dive',
      'subtitle': 'IPv6 addressing, transition, and deployment',
      'status': 'locked',
      'content': '''
# IPv6 Deep Dive

IPv6 is the long-term solution to IPv4 address exhaustion. With IoT growth and cloud expansion, IPv6 knowledge is increasingly important.

## Why IPv6?
IPv4 provides ~4.3 billion addresses — already exhausted. IPv6 provides 3.4 × 10^38 addresses — effectively unlimited.

## IPv6 Address Format
128 bits, written as 8 groups of 4 hex digits separated by colons:
**2001:0db8:85a3:0000:0000:8a2e:0370:7334**

### Shortening Rules
1. Remove leading zeros in each group: 0db8 → db8, 0000 → 0
2. Replace ONE consecutive sequence of all-zero groups with **::**
   - 2001:0db8:0000:0000:0000:0000:0000:0001 → **2001:db8::1**

## IPv6 Address Types

### Global Unicast (GUA)
Routable on the internet. Starts with **2000::/3** (2xxx or 3xxx).
Like public IPv4 addresses.

### Link-Local
Only valid on a single network segment. Starts with **FE80::/10**.
Automatically configured on every interface. Required for IPv6 to function.
Never routed beyond the local link.

### Unique Local (ULA)
Private IPv6 addresses. Starts with **FC00::/7** (FC or FD).
Like private IPv4 (RFC 1918). Not routed on the internet.

### Multicast
Starts with **FF00::/8**. Replaces IPv4 broadcast.
- **FF02::1** — All nodes on local link
- **FF02::2** — All routers on local link

### Loopback
**::1** — equivalent to 127.0.0.1 in IPv4

### Unspecified
**::** — equivalent to 0.0.0.0

## IPv6 Address Configuration

### SLAAC (Stateless Address Autoconfiguration)
Devices automatically generate their own IPv6 address:
1. Learns the network prefix from **Router Advertisement (RA)**
2. Generates an interface ID (from MAC address using EUI-64, or random)
3. Combines them to form the full address
No DHCP server required.

### DHCPv6
Similar to IPv4 DHCP but for IPv6. Two modes:
- **Stateless DHCPv6:** Provides DNS and other options, not addresses (used with SLAAC)
- **Stateful DHCPv6:** Provides full address assignment like IPv4 DHCP

### EUI-64
Generates a 64-bit interface ID from a 48-bit MAC address:
1. Split MAC in half
2. Insert **FFFE** in the middle
3. Flip the 7th bit of the first byte

## IPv6 Transition Mechanisms

### Dual Stack
Run both IPv4 and IPv6 simultaneously. Most common transition approach.

### Tunneling
Encapsulate IPv6 packets inside IPv4 packets to traverse IPv4 networks.
- **6to4:** Automatic tunneling using 2002::/16
- **Teredo:** Tunneling through NAT
- **ISATAP:** Within an organization

### NAT64 / DNS64
Allows IPv6-only clients to communicate with IPv4-only servers. Translator device converts between the two.

## NDP (Neighbor Discovery Protocol)
Replaces ARP in IPv6. Uses ICMPv6 messages.
- **Router Solicitation (RS):** Host asks for router info
- **Router Advertisement (RA):** Router announces prefix and config
- **Neighbor Solicitation (NS):** Like ARP request — who has this IP?
- **Neighbor Advertisement (NA):** Like ARP reply — I have this IP
''',
      'quizQuestions': [
        {
          'question': 'What prefix do IPv6 Link-Local addresses start with?',
          'options': ['2001::/16', 'FC00::/7', 'FE80::/10', 'FF00::/8'],
          'correctIndex': 2,
          'explanation':
              'IPv6 Link-Local addresses start with FE80::/10. They are automatically configured on every IPv6 interface and are only valid on the local link.',
        },
        {
          'question':
              'What IPv6 mechanism allows devices to automatically configure their own address without DHCP?',
          'options': ['DHCPv6', 'NDP', 'SLAAC', 'EUI-48'],
          'correctIndex': 2,
          'explanation':
              'SLAAC (Stateless Address Autoconfiguration) allows IPv6 devices to automatically generate their own address using the network prefix from Router Advertisements.',
        },
        {
          'question': 'What is the IPv6 loopback address?',
          'options': ['127.0.0.1', 'FE80::1', '::1', '0::0'],
          'correctIndex': 2,
          'explanation':
              '::1 is the IPv6 loopback address, equivalent to 127.0.0.1 in IPv4. It is used to test the local network stack.',
        },
        {
          'question': 'What does NDP replace in IPv6?',
          'options': ['DHCP', 'DNS', 'ARP', 'ICMP'],
          'correctIndex': 2,
          'explanation':
              'NDP (Neighbor Discovery Protocol) replaces ARP in IPv6, using ICMPv6 messages to resolve IPv6 addresses to link-layer addresses.',
        },
        {
          'question':
              'What transition mechanism runs both IPv4 and IPv6 simultaneously?',
          'options': ['NAT64', 'Tunneling', '6to4', 'Dual Stack'],
          'correctIndex': 3,
          'explanation':
              'Dual Stack is the most common IPv6 transition mechanism, running both IPv4 and IPv6 protocols simultaneously on network devices.',
        },
      ],
    },
    {
      'order': 17,
      'title': 'Network Automation & Programmability',
      'subtitle': 'APIs, Python, Ansible, and infrastructure as code',
      'status': 'locked',
      'content': '''
# Network Automation & Programmability

Manual network management doesn't scale. Automation reduces errors, accelerates deployments, and is now a core skill for modern network professionals.

## Why Automate Networks?
- **Speed:** Deploy changes in minutes instead of hours
- **Consistency:** No human error from manual CLI commands
- **Scale:** Manage hundreds of devices simultaneously
- **Compliance:** Enforce standards automatically
- **Rollback:** Automated recovery from failures

## Data Formats

### JSON (JavaScript Object Notation)
The most common format for APIs and modern tools. Human-readable, hierarchical.
```json
{
  "interface": {
    "name": "GigabitEthernet0/0",
    "ip_address": "192.168.1.1",
    "enabled": true
  }
}
```

### YAML
Human-friendly, used in Ansible, Kubernetes, and config files.
```yaml
interface:
  name: GigabitEthernet0/0
  ip_address: 192.168.1.1
  enabled: true
```

### XML
Older format, still used by NETCONF.

## APIs in Networking

### REST API
Most common modern API style. Uses HTTP methods:
- **GET:** Retrieve data
- **POST:** Create new resource
- **PUT/PATCH:** Update resource
- **DELETE:** Remove resource

Modern network devices expose REST APIs for configuration and monitoring.

### NETCONF
XML-based protocol for managing network devices. Uses SSH. Supports:
- Configuration management
- State retrieval
- Event notifications

### RESTCONF
REST-based version of NETCONF. Uses HTTP/JSON or XML.

## Python for Network Automation

Key Python libraries:
- **Netmiko:** SSH to network devices, run commands
- **Paramiko:** Low-level SSH library
- **NAPALM:** Vendor-neutral network automation library
- **Nornir:** Automation framework
- **Scapy:** Packet manipulation

Simple Netmiko example concept:
Connect to a device → send a command → parse the output → take action based on results.

## Ansible for Network Automation
Agentless automation tool. Uses YAML **playbooks** to define desired state.

**Key Concepts:**
- **Inventory:** List of devices to manage
- **Playbook:** YAML file defining tasks
- **Module:** Pre-built task (e.g., ios_command, eos_config)
- **Role:** Reusable collection of tasks
- **Idempotent:** Running playbook multiple times gives same result

## Infrastructure as Code (IaC)
Manage network/infrastructure through code and version control:
- **Terraform:** Declarative IaC, supports cloud and network providers
- **Git:** Version control for all configuration and automation code
- **CI/CD pipelines:** Automatically test and deploy network changes

## Intent-Based Networking (IBN)
Next evolution — describe the **desired outcome**, not the specific commands. System figures out how to implement it.
- Cisco DNA Center is an example
- Uses machine learning to verify intent is being met
- Automatically remediates when network drifts from intent

## Model-Driven Telemetry
Instead of SNMP polling, devices **stream** data in real time to monitoring systems using:
- **gRPC/gNMI:** Modern streaming telemetry protocols
- **YANG models:** Standard data models for network configuration and state
Much faster and more scalable than SNMP.
''',
      'quizQuestions': [
        {
          'question':
              'Which HTTP method is used to retrieve data from a REST API?',
          'options': ['POST', 'PUT', 'DELETE', 'GET'],
          'correctIndex': 3,
          'explanation':
              'GET is the HTTP method used to retrieve data from a REST API. POST creates, PUT/PATCH updates, and DELETE removes resources.',
        },
        {
          'question':
              'What Python library is commonly used for SSH connections to network devices?',
          'options': ['Scapy', 'Netmiko', 'Requests', 'Flask'],
          'correctIndex': 1,
          'explanation':
              'Netmiko is a Python library that simplifies SSH connections to network devices from multiple vendors, making it easy to send commands and retrieve output.',
        },
        {
          'question': 'What does "idempotent" mean in the context of Ansible?',
          'options': [
            'Runs faster each time',
            'Running multiple times produces the same result',
            'Only runs once',
            'Requires manual approval',
          ],
          'correctIndex': 1,
          'explanation':
              'Idempotent means running the playbook multiple times produces the same result — it only makes changes when the current state differs from the desired state.',
        },
        {
          'question': 'What data format does Ansible use for playbooks?',
          'options': ['JSON', 'XML', 'YAML', 'CSV'],
          'correctIndex': 2,
          'explanation':
              'Ansible uses YAML (Yet Another Markup Language) for playbooks due to its human-readable, clean syntax.',
        },
        {
          'question':
              'What is the advantage of model-driven telemetry over SNMP polling?',
          'options': [
            'Cheaper hardware required',
            'Devices stream data in real time rather than being polled',
            'No configuration needed',
            'Works without network connectivity',
          ],
          'correctIndex': 1,
          'explanation':
              'Model-driven telemetry has devices proactively stream data in real time, providing much faster and more scalable visibility than polling-based SNMP.',
        },
      ],
    },
    {
      'order': 18,
      'title': 'Data Center Networking',
      'subtitle': 'Modern data center design, fabrics, and technologies',
      'status': 'locked',
      'content': '''
# Data Center Networking

Data centers are the backbone of modern IT. Understanding data center networking is critical for cloud, virtualization, and enterprise roles.

## Data Center Network Design

### Traditional Three-Tier
Core → Aggregation → Access. Works but has limitations:
- STP required, wastes bandwidth
- East-West traffic bottleneck (server to server in same DC)
- Doesn't scale well

### Spine-Leaf (Clos Network)
Modern standard for data centers:
- **Leaf switches:** Connect servers, storage, and uplink to all spines
- **Spine switches:** Connect only to leaf switches, no server connections
- **Every leaf connects to every spine** — equal cost paths, no STP
- **ECMP (Equal Cost Multi-Path):** Load balances across all spine uplinks
- Consistent latency: any server to any server = 2 hops

### Oversubscription
Ratio of server bandwidth to uplink bandwidth. A 4:1 oversubscription means 400Gbps of servers sharing 100Gbps uplink. Acceptable for bursty workloads.

## Data Center Interconnect (DCI)
Connecting multiple data centers for:
- **Disaster Recovery (DR)**
- **Active-Active operations**
- **Data migration**

Technologies:
- Dark fiber
- DWDM (Dense Wavelength Division Multiplexing) — multiple optical channels on one fiber
- OTV (Overlay Transport Virtualization) — extends VLANs across DCI
- VXLAN over DCI links

## Virtualization & Networking

### Server Virtualization
Multiple VMs run on one physical server. Each VM needs network connectivity.
- **Virtual Switch (vSwitch):** Software switch inside the hypervisor
- **Port groups:** VLAN assignments for VMs
- **VMware vDS / Cisco ACI:** Advanced virtual networking platforms

### VXLAN (Virtual Extensible LAN)
Encapsulates Layer 2 frames in UDP packets, enabling:
- Layer 2 connectivity over Layer 3 networks
- Up to 16 million segments (vs 4096 VLANs)
- Essential for modern data centers and cloud

**VTEP (VXLAN Tunnel Endpoint):** The device that encapsulates/decapsulates VXLAN traffic.

## Storage Networking

### SAN (Storage Area Network)
Dedicated network for storage traffic.
- **Fibre Channel (FC):** Traditional SAN protocol. Very fast, low latency.
- **iSCSI:** SCSI over IP. Runs on standard Ethernet.
- **FCoE (Fibre Channel over Ethernet):** Converged FC and Ethernet.

### NAS (Network Attached Storage)
File-based storage accessed over standard IP network.
- **NFS:** Unix/Linux file sharing
- **SMB/CIFS:** Windows file sharing

## Data Center Infrastructure

### Power
- **UPS (Uninterruptible Power Supply):** Battery backup for brief outages
- **PDU (Power Distribution Unit):** Distributes power to rack equipment
- **Redundant power feeds:** Two independent power sources per rack

### Cooling
- Hot aisle/cold aisle containment
- Precision air conditioning units (CRAC/CRAH)
- In-row cooling for high-density deployments

### Tiers (Uptime Institute)
| Tier | Availability | Redundancy |
|---|---|---|
| I | 99.671% | None |
| II | 99.741% | Partial |
| III | 99.982% | N+1, concurrent maintainability |
| IV | 99.995% | 2N, fault tolerant |
''',
      'quizQuestions': [
        {
          'question':
              'In Spine-Leaf architecture, how many hops does traffic take between any two servers?',
          'options': ['1 hop', '2 hops', '3 hops', 'Variable'],
          'correctIndex': 1,
          'explanation':
              'In Spine-Leaf, any server-to-server communication takes exactly 2 hops (leaf → spine → leaf), providing consistent, predictable latency.',
        },
        {
          'question': 'What does VXLAN extend?',
          'options': [
            'IP routing over Layer 2',
            'Layer 2 networks over Layer 3 infrastructure',
            'VLAN count beyond 4096',
            'Both B and C',
          ],
          'correctIndex': 3,
          'explanation':
              'VXLAN extends Layer 2 over Layer 3 networks AND increases the segment limit from 4096 VLANs to over 16 million VXLAN Network Identifiers (VNIs).',
        },
        {
          'question':
              'Which storage protocol runs SCSI commands over a standard IP network?',
          'options': ['Fibre Channel', 'FCoE', 'iSCSI', 'NFS'],
          'correctIndex': 2,
          'explanation':
              'iSCSI runs SCSI storage commands over standard IP/Ethernet networks, allowing SANs to be built without dedicated Fibre Channel infrastructure.',
        },
        {
          'question':
              'What Uptime Institute tier requires fault tolerance with 2N redundancy?',
          'options': ['Tier I', 'Tier II', 'Tier III', 'Tier IV'],
          'correctIndex': 3,
          'explanation':
              'Tier IV data centers require 2N (fully redundant) systems with 99.995% availability. Any single failure cannot cause downtime.',
        },
        {
          'question': 'What does ECMP stand for and what does it do?',
          'options': [
            'Extended Cable Management Protocol — manages cables',
            'Equal Cost Multi-Path — load balances across multiple paths',
            'Encrypted Content Management Protocol — secures data',
            'External Connection Management Point — manages external links',
          ],
          'correctIndex': 1,
          'explanation':
              'ECMP (Equal Cost Multi-Path) load balances traffic across multiple paths of equal cost, used in Spine-Leaf to utilize all spine uplinks simultaneously.',
        },
      ],
    },
    {
      'order': 19,
      'title': 'Network Compliance & Documentation',
      'subtitle':
          'Standards, compliance frameworks, and professional documentation',
      'status': 'locked',
      'content': '''
# Network Compliance & Documentation

Professional networks require more than technical competence — they require compliance with regulations, standards, and meticulous documentation.

## Why Compliance Matters
- **Legal requirements:** Avoid fines and legal liability
- **Security:** Compliance frameworks encode security best practices
- **Business continuity:** Structured processes reduce outages
- **Trust:** Customers and partners expect compliant organizations
- **Audit readiness:** Demonstrate controls when audited

## Key Compliance Frameworks

### PCI DSS (Payment Card Industry Data Security Standard)
Required for organizations that handle credit card data.
- Network segmentation required to isolate cardholder data environment (CDE)
- Firewalls required at all entry points
- Quarterly vulnerability scans
- Annual penetration testing
- All traffic encrypted

### HIPAA (Health Insurance Portability and Accountability Act)
US regulation for healthcare data. Network requirements include:
- Access controls and audit logs
- Encryption of data in transit
- Network segmentation for PHI (Protected Health Information)

### SOC 2
Auditing standard for service organizations. Covers:
- Security
- Availability
- Processing integrity
- Confidentiality
- Privacy

### ISO 27001
International standard for information security management systems (ISMS). Comprehensive framework covering all aspects of security.

### NIST Cybersecurity Framework
US government framework with five functions:
1. **Identify** — asset management, risk assessment
2. **Protect** — access control, training, data security
3. **Detect** — monitoring, anomaly detection
4. **Respond** — incident response planning
5. **Recover** — recovery planning, improvements

## Network Documentation Standards

### What to Document
- **Physical topology:** Actual cable connections, rack locations, device models
- **Logical topology:** VLANs, IP addressing, routing
- **IP address management (IPAM):** Who owns what IP
- **Change log:** All changes made, by whom, when, and why
- **Standard configurations:** Baseline configs for each device type
- **Runbooks:** Step-by-step procedures for common tasks
- **Incident records:** What happened, how it was resolved

### Diagram Tools
- **Visio:** Industry standard for network diagrams
- **Lucidchart / Draw.io:** Cloud-based, collaborative
- **NetBrain:** Auto-discovers and documents networks

### Naming Conventions
Consistent naming makes management easier:
- Include: location, device type, number
- Example: **NYC-SW-01** (New York City, Switch, number 1)
- Document the convention and enforce it

## Change Management
All network changes should follow a process:
1. **Request:** Document what change is needed and why
2. **Impact assessment:** What could go wrong?
3. **Approval:** CAB or manager sign-off
4. **Implementation window:** Schedule maintenance window
5. **Testing:** Verify change worked
6. **Rollback plan:** How to undo if it fails
7. **Documentation:** Update diagrams and records

## Disaster Recovery (DR) Planning

### Key Metrics
- **RTO (Recovery Time Objective):** Maximum acceptable downtime
- **RPO (Recovery Point Objective):** Maximum acceptable data loss

### DR Strategies
- **Cold site:** Empty facility, long recovery time
- **Warm site:** Partially equipped, moderate recovery time
- **Hot site:** Fully operational duplicate, near-instant failover
- **Cloud DR:** Use cloud resources as DR target

## Security Policies
Document your security posture:
- **Acceptable Use Policy (AUP)**
- **Network Security Policy**
- **Incident Response Plan**
- **Password Policy**
- **Remote Access Policy**
''',
      'quizQuestions': [
        {
          'question':
              'Which compliance framework is required for organizations handling credit card data?',
          'options': ['HIPAA', 'SOC 2', 'PCI DSS', 'ISO 27001'],
          'correctIndex': 2,
          'explanation':
              'PCI DSS (Payment Card Industry Data Security Standard) is required for any organization that stores, processes, or transmits credit card data.',
        },
        {
          'question': 'What does RPO stand for in disaster recovery?',
          'options': [
            'Recovery Point Objective',
            'Recovery Process Order',
            'Redundancy Planning Operation',
            'Restore Protocol Option',
          ],
          'correctIndex': 0,
          'explanation':
              'RPO (Recovery Point Objective) defines the maximum acceptable amount of data loss measured in time — e.g., RPO of 1 hour means you can lose at most 1 hour of data.',
        },
        {
          'question':
              'What are the five functions of the NIST Cybersecurity Framework?',
          'options': [
            'Plan, Design, Build, Test, Deploy',
            'Identify, Protect, Detect, Respond, Recover',
            'Assess, Mitigate, Monitor, Report, Review',
            'Prevent, Detect, Contain, Eradicate, Recover',
          ],
          'correctIndex': 1,
          'explanation':
              'The NIST Cybersecurity Framework\'s five core functions are: Identify, Protect, Detect, Respond, and Recover.',
        },
        {
          'question': 'What is a hot site in disaster recovery?',
          'options': [
            'A backup site with no equipment',
            'A partially equipped backup facility',
            'A fully operational duplicate ready for immediate failover',
            'A cloud-only backup',
          ],
          'correctIndex': 2,
          'explanation':
              'A hot site is a fully equipped, operational duplicate of the primary site that can take over almost immediately if the primary site fails.',
        },
        {
          'question':
              'What should always be included when documenting a network change?',
          'options': [
            'Only what was changed',
            'What changed, who made it, when, why, and rollback plan',
            'Just the ticket number',
            'Before/after screenshots only',
          ],
          'correctIndex': 1,
          'explanation':
              'Complete change documentation includes what was changed, who made the change, when it was made, why it was needed, testing results, and a rollback plan.',
        },
      ],
    },
    {
      'order': 20,
      'title': 'Final Exam Preparation',
      'subtitle': 'Review, practice scenarios, and exam strategy',
      'status': 'locked',
      'content': '''
# Final Exam Preparation

Congratulations on reaching the final module! This section reviews key concepts, provides exam scenarios, and prepares you to demonstrate Network Professional competency.

## Core Concepts Review

### Networking Fundamentals
- OSI model — 7 layers, PDUs, devices at each layer
- TCP/IP — 4 layers, key protocols at each
- TCP vs UDP — when to use each
- Key port numbers (80, 443, 22, 25, 53, 67/68, 161/162, 3389)

### Addressing & Subnetting
- IPv4 classes and private ranges
- Subnet mask to CIDR conversion
- Calculate: network address, broadcast, usable hosts
- IPv6 types: GUA, link-local, ULA, multicast
- SLAAC vs DHCPv6

### Switching
- MAC address table operation
- VLANs — access vs trunk ports, 802.1Q
- STP — preventing loops, port states
- Inter-VLAN routing methods

### Routing
- Routing table — how decisions are made
- Static vs dynamic routing
- Administrative distance values
- OSPF, EIGRP, BGP — use cases
- NAT types — static, dynamic, PAT

### Security
- Firewall types — packet filter, stateful, NGFW
- VPN types — site-to-site, remote access, SSL
- IDS vs IPS
- Common attacks — DoS, MitM, ARP spoofing
- ACLs — standard vs extended

### Wireless
- 802.11 standards and frequencies
- Non-overlapping channels (1, 6, 11 on 2.4 GHz)
- WEP (broken), WPA, WPA2, WPA3
- Infrastructure modes

## Exam Scenario Practice

### Scenario 1: Connectivity Issue
*A user cannot reach the internet but can ping their default gateway.*
→ Gateway is reachable (Layer 1-3 local OK). Issue is likely upstream routing, NAT, or ISP.

### Scenario 2: VLAN Communication
*Two devices on the same switch cannot communicate.*
→ Check if they are on the same VLAN. If different VLANs, need inter-VLAN routing.

### Scenario 3: Slow Network
*Users report slow performance only to a specific server.*
→ Check server NIC, switch port errors, duplex mismatch, bandwidth utilization on server-side link.

### Scenario 4: DHCP Not Working
*New devices can't get IP addresses.*
→ Check DHCP server is running, scope has available addresses, relay agent configured if on different subnet.

### Scenario 5: DNS Failure
*Users can ping IPs but not hostnames.*
→ DNS resolution failing. Check DNS server setting on clients, verify DNS server is responding (nslookup).

## Key Command Reference

| Task | Command |
|---|---|
| Test connectivity | ping [ip/hostname] |
| Trace path | traceroute / tracert |
| View IP config | ipconfig /all (Win), ip addr (Linux) |
| DNS lookup | nslookup [hostname] |
| View ARP cache | arp -a |
| View routing table | netstat -r / ip route |
| View connections | netstat -an |

## Exam Strategy
1. **Read questions carefully** — look for keywords like "MOST likely," "BEST," "FIRST"
2. **Eliminate obviously wrong answers** — usually 1-2 clear distractors
3. **Consider the scenario context** — what problem is being solved?
4. **Apply OSI model thinking** — what layer is the issue at?
5. **Trust your preparation** — you've covered all the material

## What's Next After Certification
- **Binary Cybersecurity Professional** — build on networking with security specialization
- **Binary Cloud Professional** — apply networking knowledge in cloud environments
- **Hands-on labs** — practice with GNS3, Cisco Packet Tracer, or real hardware
- **Home lab** — even basic switches and routers provide invaluable experience

You've built a strong foundation. Network professionals are in high demand — this certification demonstrates real, applicable knowledge.
''',
      'quizQuestions': [
        {
          'question':
              'A user can ping their default gateway but cannot reach the internet. Where is the problem most likely?',
          'options': [
            'Physical cable issue',
            'NIC failure',
            'Upstream routing, NAT, or ISP issue',
            'DNS failure',
          ],
          'correctIndex': 2,
          'explanation':
              'If the gateway is reachable, the local network is fine. The issue is beyond the gateway — upstream routing, NAT misconfiguration, or the ISP.',
        },
        {
          'question':
              'Two devices on the same switch cannot communicate. What should you check first?',
          'options': [
            'Routing table',
            'VLAN assignment',
            'Firewall rules',
            'DNS settings',
          ],
          'correctIndex': 1,
          'explanation':
              'Devices on the same switch but different VLANs cannot communicate without inter-VLAN routing. VLAN assignment is the first thing to check.',
        },
        {
          'question': 'What is the administrative distance of OSPF?',
          'options': ['90', '100', '110', '120'],
          'correctIndex': 2,
          'explanation':
              'OSPF has an administrative distance of 110. EIGRP is 90 (more trusted), RIP is 120 (less trusted).',
        },
        {
          'question': 'Which command would you use to test DNS resolution?',
          'options': ['ping', 'traceroute', 'netstat', 'nslookup'],
          'correctIndex': 3,
          'explanation':
              'nslookup (and dig on Linux) directly queries DNS servers to test name resolution, showing what IP address a hostname resolves to.',
        },
        {
          'question':
              'What is the maximum number of VLANs supported with 802.1Q tagging?',
          'options': ['256', '1024', '4096', '16 million'],
          'correctIndex': 2,
          'explanation':
              '802.1Q supports 4096 VLANs (using a 12-bit VLAN ID field, 2^12 = 4096). VXLAN extends this to over 16 million.',
        },
      ],
    },
  ];

  final batch = db.batch();
  for (final module in modules) {
    final moduleRef = courseRef
        .collection('modules')
        .doc('module-${module['order']}');
    final questions = module['quizQuestions'] as List<Map<String, dynamic>>;
    final moduleData = Map<String, dynamic>.from(module)
      ..remove('quizQuestions');
    batch.set(moduleRef, moduleData);

    for (int i = 0; i < questions.length; i++) {
      final qRef = moduleRef.collection('quizQuestions').doc('q$i');
      batch.set(qRef, questions[i]);
    }
  }

  await batch.commit();
  print('✅ Binary Network Professional seeded successfully (20 modules)');
}
