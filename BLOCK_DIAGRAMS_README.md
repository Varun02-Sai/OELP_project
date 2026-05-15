# UCIe TX 2.0: Full Architecture Block & Circuit Diagrams

This document outlines the entire UCIe 2.0 Transmitter (TX) behavioral model. It maps the software/MATLAB algorithms directly into architectural and electrical circuit equivalents, featuring series/parallel layouts and standard values explicitly drawn from the UCIe 32 GT/s System-Level specification (MathWorks reference).

---

## 🌟 The Unified System Overview (Grand Block Diagram)

Below is the complete path of a bit traversing from the internal silicon logic of the transmitter chip, out through its package physical pads, across the channel trace, and finally terminating inside the receiver pad.

```mermaid
graph TD
    classDef signal fill:#e1f5fe,stroke:#01579b,stroke-width:2px;
    classDef logic fill:#fff3e0,stroke:#e65100,stroke-width:2px;
    classDef hardware fill:#f3e5f5,stroke:#4a148c,stroke-width:2px;
    classDef metric fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px;

    subgraph "1. Data Generation (Digital)"
        Start([PRBS Random Bits 0,1<br/>32 GT/s]):::logic --> NRZ[NRZ Polar Mapper<br/>0 &rarr; -1, 1 &rarr; +1]:::logic
        NRZ --> UPS[Zero-Order Hold<br/>Interpolate 16x<br/>fs = 512 GHz]:::logic
    end

    subgraph "2. TX Feed-Forward Equalizer (DSP)"
        UPS --> FFE_In[FFE Input sym_n]:::logic
        FFE_In --> M1(("x 0.75<br/>Gain c0")):::logic
        FFE_In --> D1["Unit Delay<br/>(z^-1)"]:::logic
        D1 --> M2(("x -0.25<br/>Gain c1")):::logic
        M1 --> FFE_ADD(("+")):::logic
        M2 --> FFE_ADD
        FFE_ADD --> FFE_Out(("Scale to <br/>Vswing = 0.625V")):::logic
    end

    subgraph "3. Driver Analog Limit"
        FFE_Out --> Edge["Single-Pole Low Pass Filter<br/>Sets Trise = 12.5ps<br/>f_3dB = 28 GHz"]:::hardware
    end
    
    subgraph "4. TX Impedance & Package Parasitics"
        Edge --> Rtx("R_out = 30 &Omega;<br/>(Series Impedance)"):::hardware 
        Rtx --> NodeTX(("TX Pad Pin")):::signal
        NodeTX --> Ctx("C_out = 0.125 pF<br/>(Parallel to GND)"):::hardware
        Ctx -.-> GND1(Ground):::hardware
    end
    
    subgraph "5. Multi-Die Interconnect"
        NodeTX --> Channel["Lossy Transmission Line<br/>Attenuation: -2.0 dB @ 16 GHz"]:::hardware
    end
    
    subgraph "6. RX Far-End Load"
        Channel --> NodeRX(("RX Pad Pin")):::signal
        NodeRX --> Rrx("R_in = 50 &Omega;<br/>(Parallel Term to GND)"):::hardware
        NodeRX --> Crx("C_in = 0.125 pF<br/>(Parallel Cap to GND)"):::hardware
        Rrx -.-> GND2(Ground):::hardware
        Crx -.-> GND3(Ground):::hardware
    end
    
    subgraph "7. Environment & Evaluation"
        NodeRX --> EvalAdd(("+")):::logic
        Noise["Additive Voltage Noise<br/>AWGN &sigma;_V = 5 mV"] -.-> EvalAdd:::logic
        EvalAdd --> Eval["Data Slicer & BER<br/>Target = 1e-15"]:::metric
        Jitter["Sampling Jitter<br/>RJ &sigma;_RJ = 0.25 ps"] -.-> Eval:::logic
    end
```

---

## Detailed Block Diagrams (Step-by-Step Breakdown)

Here is how each sub-system is isolated and mathematically implemented based on specific operational values.

### 1. PRBS & NRZ Stimulus Generator
**What it does:** Simulates generating target silicon data at high speeds (32 Trillion logic operations per second).
- **Values:** Data Rate = 32 GT/s. Symbol Time (UI) = 31.25 ps. Sample Rate (fs) = 512 GHz.
- **Operations:** Converts binary to signed analog logic variables (+1, -1), then clocks them into continuous arrays multiplying it out by 16 times per interval.

```mermaid
graph LR
    A[Random Bits<br/>0 and 1] --> B[NRZ Mapping<br/>0 &rarr; -1 <br/> 1 &rarr; +1]
    B --> C[Zero-Order Hold<br/>Hold values for 16 samples]
    C --> D[High-Speed Ideal Waveform]
```

### 2. TX Feed-Forward Equalizer (FFE)
**What it does:** Corrects for line losses by shaping current before it leaves the chip.
- **Values:** Total target Swing (`Vswing`) = 0.625 V. Taps vary (e.g., Preset 3: Main Tap `c0` = 0.75, Post Tap `c1` = -0.25).
- **Circuit/Logic:** Parallel signal paths. The original signal path multiplies by `c0` directly. A secondary path places the signal in a memory delay buffer (Delay $Z^{-1}$), multiplies it by `c1`, and **Adds** both into the outgoing voltage pipeline.

```mermaid
graph LR
    In["x[n]"] --> M1(("x 0.75<br/>(Main Tap)"))
    In --> D1["Delay<br/>(z^-1)"]
    D1 --> M2(("x -0.25<br/>(Post Tap)"))
    M1 --> ADD(("+"))
    M2 --> ADD
    ADD --> Mult(("Scale via<br/>Vswing = 0.625V"))
    Mult --> Y["FFE Waveform"]
```

### 3. TX Edge Shaping (Rise Time Filter)
**What it does:** Drivers cannot instantaneously swap from -0.312V to +0.312V. They stretch over time.
- **Values:** Target Rise time ($t_{rise}$) = 12.5 ps. Using formula $f_{3dB} \approx 0.35 / t_{rise}$, Bandwidth cut is isolated to 28 GHz.
- **Circuit/Logic:** Models the transistor's raw analog saturation capabilities as a digital Single-Pole mathematically cascaded Low-Pass Filter.

```mermaid
graph LR
    X[In] --> LPF["Driver Saturation (Low Pass Filter)<br/>f_3dB = 28 GHz<br/>Continuous to Discrete Bilinear math"] --> Y[Out]
```

### 4. TX Impedance & Package Parasitics (Leaving the Chip)
**What is happening?** The signal is trying to physically leave the transmitter silicon die through a microscopic metal pad.
* **The Resistor ($R_{out}$ Series):** In plumbing, if you have infinite pressure, you burst the pipes. To prevent the chip from destroying itself by driving infinite current, an intentional 30 $\Omega$ resistor is placed in the way to choke the current.
* **The Capacitor ($C_{out}$ Parallel):** The metal pad on the chip physically acts like a tiny puddle/reservoir (parasitic capacitance). Before the voltage can push down the wire, it has to "fill up" this puddle. This steals the initial burst of energy and causes your sharp, fast digital signal edges to slow down and slump.

```mermaid
graph LR
    classDef wire fill:#none,stroke:#ff9800,stroke-width:2px;
    classDef comp fill:#f5f5f5,stroke:#424242,stroke-width:2px;

    In[Digital Signal] --> R("R_out: 30 &Omega;<br/>(Restricts Current Flow)"):::comp
    R --> Node((The Physical Pad)):::wire
    Node --> C("C_out: 0.125 pF<br/>(Steals Energy to 'fill up')"):::comp
    C -.-> GND(Ground Dump):::wire
    Node --> Out[Signal forced out to Channel]:::wire
```

### 5. Multi-Die Interconnect (The Channel)
**What is happening?** The signal is now traveling across the physical microscopic wires (traces) connecting Chip A to Chip B.
* At 32 GT/s, electricity is switching directions 32 billion times a second. At these extreme speeds, the wire stops acting like a perfect pipe.
* **Skin Effect & Dielectric Loss:** The electrons start riding violently on the outside skin of the copper, turning into heat. Furthermore, the insulation (plastic) around the wire absorbs the ultra-fast AC transitions.
* **The Result:** Sharp, rapid transitions get heavily erased and swallowed, while long, held signals survive. We measure this "swallowing" as a -2.0 dB loss (getting weaker) at high frequencies (16.0 GHz).

```mermaid
graph LR
    classDef trace fill:#e8eaf6,stroke:#3f51b5,stroke-width:3px;
    
    In[Signal entering wire] --> Channel["The Interconnect Wire<br/>Acts as a physical brake on fast signals.<br/>Rapid changes melt into heat (-2.0 dB loss)"]:::trace
    Channel --> Out[Signal arriving weak and rounded]
```

### 6. RX Far-End Load (Arriving at the Receiver)
**What is happening?** The signal has arrived at the destination chip (the receiver) and must enter it.
* **The Resistor ($R_{in}$ Parallel):** If you shoot high-pressure water down a pipe and it hits a solid wall at the end, it will violently splash backwards. In electrical traces, this is called **Signal Reflection**. The returning "ghost signal" crashes into incoming signals and destroys them. To stop this, we open a 50 $\Omega$ drain at the end (Parallel to Ground). It perfectly, safely absorbs the incoming signal pressure like an infinity pool, killing reflections.
* **The Capacitor ($C_{in}$ Parallel):** Just like the transmitter, the receiver has a metal pad that acts like a puddle (0.125 pF). The incoming signal must "fill up" this puddle before the receiver can read it, rounding off the signal's edges one final time.

```mermaid
graph LR
    classDef wire fill:#none,stroke:#ff9800,stroke-width:2px;
    classDef comp fill:#f5f5f5,stroke:#424242,stroke-width:2px;

    In[Weak incoming Channel signal] --> Node((The Receiving Pad)):::wire
    Node --> R_rx("R_in: 50 &Omega;<br/>(Absorbs signal to stop reflection)"):::comp
    Node --> C_rx("C_in: 0.125 pF<br/>(Forces the signal to fill it up)"):::comp
    R_rx -.-> GND1(Ground):::wire
    C_rx -.-> GND2(Ground):::wire
    Node --> Out[Final Inside Receiver Signal]:::wire
```

### 7. Environment & Evaluation (Factoring the Real World)
**What is happening?** Everything previous assumes a perfect universe. But the inside of a computer is chaotic.
* **Additive Voltage Noise (AWGN):** Other wires are buzzing right next to ours (Cross-talk). The Power Supply is rippling. Millions of other transistors are switching. This causes our signal's height/voltage to bounce up and down randomly by roughly 5 mV.
* **Sampling Jitter:** The computer's internal clock heartbeat ticks to say *"Read the value NOW"*. But that heartbeat isn't perfect; occasionally it ticks 0.25 ps too early or too late.
* **The Slicer (BER):** You now have a short, rounded, blurry, shaky signal. The receiver looks directly at the center of the time window. If the voltage is above 0, it guesses the bit is a `1`. If below 0, it guesses `0`. We compare that against what we actually sent in Step 1 to calculate our **Bit Error Rate (BER)**.

```mermaid
graph LR
    classDef env fill:#ffebee,stroke:#d32f2f,stroke-width:2px;
    classDef eval fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;

    In[The exact analog wave] --> ADD(("+"))
    Noise["Real World Heat & Magnetics<br/>Causes Voltage to jump up/down"]:::env -.-> ADD
    ADD --> Out[The Blurry, Noisy Wave]
    Out --> Eval["The Receiver Brain<br/>Guesses 1s and 0s<br/>Compares guess to original data"]:::eval
    Jitter["Imperfect Clock<br/>Shakes the checking time left/right"]:::env -.-> Eval
```

---

### The Big Picture (All Analog Steps Combined)

When you stitch the physical sequence together, the entire second half of your code is essentially doing this:

1. **Step 4:** Shoving the mathematical signal out of the chip, losing speed to the pad's impedance.
2. **Step 5:** Pushing it through a tiny wire where speed creates heat, weakening the signal.
3. **Step 6:** Catching it at the far end, using a terminator to stop the signal from bouncing backward, while losing speed to the final pad.
4. **Step 7:** Imposing random real-world shaking/noise to it, and making a blind guess if it's still recognizable as a `1` or `0`.

```mermaid
graph TD
    classDef p_tx fill:#f3e5f5,stroke:#4a148c,stroke-width:2px;
    classDef p_ch fill:#e8eaf6,stroke:#3f51b5,stroke-width:2px;
    classDef p_rx fill:#e0f7fa,stroke:#006064,stroke-width:2px;
    classDef p_env fill:#ffebee,stroke:#d32f2f,stroke-width:2px;

    %% Step 4 TX
    subgraph "Step 4: Transmitter Escape (TX Pad)"
        In[Clean Digital Signal] --> Rtx("Restricting Resistor (30 &Omega;)"):::p_tx 
        Rtx --> NodeTX(("TX Pad Pin"))
        NodeTX --> Ctx("Energy-Stealing Puddle<br/>(0.125 pF)"):::p_tx
        Ctx -.-> GND1(Ground)
    end
    
    %% Step 5 CH
    subgraph "Step 5: The Journey (Interconnect)"
        NodeTX --> Channel["Copper Trace<br/>Absorbs High Frequencies as Heat"]:::p_ch
    end
    
    %% Step 6 RX
    subgraph "Step 6: Receiver Catch (RX Pad)"
        Channel --> NodeRX(("RX Pad Pin"))
        NodeRX --> Rrx("Reflection Killer Drain<br/>(50 &Omega;)"):::p_rx
        NodeRX --> Crx("RX Energy-Stealing Puddle<br/>(0.125 pF)"):::p_rx
        Rrx -.-> GND2(Ground)
        Crx -.-> GND3(Ground)
    end
    
    %% Step 7 ENV
    subgraph "Step 7: The Real World Check"
        NodeRX --> EvalAdd(("+")):::p_env
        Noise["Voltage Bouncing<br/>(Cross-talk/Noise)"] -.-> EvalAdd:::p_env
        EvalAdd --> Eval["Final Slicer: Is it > 0 Volts?"]
        Jitter["Clock Shaking<br/>(Jitter)"] -.-> Eval:::p_env
    end
```
