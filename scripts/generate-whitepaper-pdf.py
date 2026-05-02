#!/usr/bin/env python3
"""Generate an academic-style PDF whitepaper for BlastShield."""

import os
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib.colors import HexColor, black
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, HRFlowable, ListFlowable, ListItem
)
from reportlab.platypus.flowables import KeepTogether

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "docs", "public")
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "blastshield-whitepaper.pdf")

os.makedirs(OUTPUT_DIR, exist_ok=True)

# Colors
ACCENT = HexColor("#1a1a2e")
ACCENT_LIGHT = HexColor("#e8e8f0")
LINK_COLOR = HexColor("#2563eb")
TABLE_HEADER_BG = HexColor("#1a1a2e")
TABLE_HEADER_FG = HexColor("#ffffff")
TABLE_ALT_BG = HexColor("#f5f5f5")

# Document setup
doc = SimpleDocTemplate(
    OUTPUT_FILE,
    pagesize=letter,
    leftMargin=1.0 * inch,
    rightMargin=1.0 * inch,
    topMargin=1.0 * inch,
    bottomMargin=1.0 * inch,
)

# Styles
styles = getSampleStyleSheet()

title_style = ParagraphStyle(
    "WhitepaperTitle",
    parent=styles["Title"],
    fontSize=24,
    leading=30,
    spaceAfter=6,
    textColor=ACCENT,
    alignment=TA_CENTER,
    fontName="Times-Bold",
)

subtitle_style = ParagraphStyle(
    "WhitepaperSubtitle",
    parent=styles["Normal"],
    fontSize=13,
    leading=18,
    spaceAfter=4,
    textColor=HexColor("#555555"),
    alignment=TA_CENTER,
    fontName="Times-Italic",
)

author_style = ParagraphStyle(
    "AuthorLine",
    parent=styles["Normal"],
    fontSize=11,
    leading=16,
    spaceAfter=4,
    textColor=black,
    alignment=TA_CENTER,
    fontName="Times-Roman",
)

abstract_style = ParagraphStyle(
    "Abstract",
    parent=styles["Normal"],
    fontSize=10,
    leading=14,
    spaceAfter=12,
    textColor=HexColor("#333333"),
    alignment=TA_JUSTIFY,
    fontName="Times-Italic",
    leftIndent=36,
    rightIndent=36,
)

abstract_label = ParagraphStyle(
    "AbstractLabel",
    parent=styles["Normal"],
    fontSize=10,
    leading=14,
    spaceAfter=6,
    textColor=black,
    alignment=TA_CENTER,
    fontName="Times-Bold",
)

h1_style = ParagraphStyle(
    "H1",
    parent=styles["Heading1"],
    fontSize=16,
    leading=22,
    spaceBefore=24,
    spaceAfter=10,
    textColor=ACCENT,
    fontName="Times-Bold",
)

h2_style = ParagraphStyle(
    "H2",
    parent=styles["Heading2"],
    fontSize=13,
    leading=18,
    spaceBefore=18,
    spaceAfter=8,
    textColor=ACCENT,
    fontName="Times-Bold",
)

h3_style = ParagraphStyle(
    "H3",
    parent=styles["Heading3"],
    fontSize=11,
    leading=16,
    spaceBefore=14,
    spaceAfter=6,
    textColor=HexColor("#333333"),
    fontName="Times-BoldItalic",
)

body_style = ParagraphStyle(
    "Body",
    parent=styles["Normal"],
    fontSize=10,
    leading=14,
    spaceAfter=8,
    alignment=TA_JUSTIFY,
    fontName="Times-Roman",
)

bullet_style = ParagraphStyle(
    "Bullet",
    parent=body_style,
    leftIndent=24,
    bulletIndent=12,
    spaceAfter=4,
)

numbered_style = ParagraphStyle(
    "Numbered",
    parent=body_style,
    leftIndent=24,
    bulletIndent=12,
    spaceAfter=4,
)

caption_style = ParagraphStyle(
    "Caption",
    parent=styles["Normal"],
    fontSize=9,
    leading=12,
    spaceAfter=12,
    spaceBefore=4,
    textColor=HexColor("#555555"),
    alignment=TA_CENTER,
    fontName="Times-Italic",
)

code_style = ParagraphStyle(
    "Code",
    parent=styles["Code"],
    fontSize=8.5,
    leading=11,
    fontName="Courier",
    backColor=HexColor("#f5f5f5"),
    leftIndent=18,
    rightIndent=18,
    spaceBefore=6,
    spaceAfter=6,
    borderPadding=6,
)

severity_high = ParagraphStyle("SevHigh", parent=body_style, textColor=HexColor("#dc2626"), fontName="Times-Bold")
severity_medium = ParagraphStyle("SevMed", parent=body_style, textColor=HexColor("#d97706"), fontName="Times-Bold")
severity_low = ParagraphStyle("SevLow", parent=body_style, textColor=HexColor("#16a34a"), fontName="Times-Bold")
severity_lt = ParagraphStyle("SevLT", parent=body_style, textColor=HexColor("#6b7280"), fontName="Times-Bold")


def make_table(headers, rows, col_widths=None):
    """Create an academic-style table."""
    header_paras = [Paragraph(h, ParagraphStyle("TH", parent=body_style, fontName="Times-Bold", fontSize=9, textColor=TABLE_HEADER_FG)) for h in headers]
    data = [header_paras]
    cell_style = ParagraphStyle("TD", parent=body_style, fontSize=9, leading=12)
    for row in rows:
        data.append([Paragraph(str(c), cell_style) for c in row])

    if col_widths is None:
        col_widths = [doc.width / len(headers)] * len(headers)

    t = Table(data, colWidths=col_widths, repeatRows=1)
    style_cmds = [
        ("BACKGROUND", (0, 0), (-1, 0), TABLE_HEADER_BG),
        ("TEXTCOLOR", (0, 0), (-1, 0), TABLE_HEADER_FG),
        ("FONTNAME", (0, 0), (-1, 0), "Times-Bold"),
        ("FONTSIZE", (0, 0), (-1, 0), 9),
        ("BOTTOMPADDING", (0, 0), (-1, 0), 8),
        ("TOPPADDING", (0, 0), (-1, 0), 8),
        ("GRID", (0, 0), (-1, -1), 0.5, HexColor("#cccccc")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 1), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 1), (-1, -1), 4),
    ]
    for i in range(1, len(data)):
        if i % 2 == 0:
            style_cmds.append(("BACKGROUND", (0, i), (-1, i), TABLE_ALT_BG))
    t.setStyle(TableStyle(style_cmds))
    return t


def sev(severity_text):
    """Return a colored severity paragraph."""
    mapping = {
        "High": severity_high,
        "Medium": severity_medium,
        "Low": severity_low,
        "Long-term": severity_lt,
        "Unknown": severity_lt,
    }
    style = mapping.get(severity_text, body_style)
    return Paragraph(f"<b>Severity: {severity_text}</b>", style)


# Build document
story = []

# Title page
story.append(Spacer(1, 1.5 * inch))
story.append(Paragraph("BlastShield", title_style))
story.append(Spacer(1, 8))
story.append(Paragraph("Kernel-Level Protection for AI Coding Agents<br/>Against Destructive Cloud CLI Commands", subtitle_style))
story.append(Spacer(1, 24))
story.append(HRFlowable(width="40%", thickness=1, color=HexColor("#cccccc"), spaceAfter=18, spaceBefore=0, hAlign="CENTER"))
story.append(Paragraph("Cedar Labs", author_style))
story.append(Paragraph("April 2026", author_style))
story.append(Spacer(1, 36))

# Abstract
story.append(Paragraph("Abstract", abstract_label))
story.append(Paragraph(
    "AI coding agents now operate with near-unrestricted access to developer machines, including the ability to execute "
    "destructive cloud infrastructure commands and install arbitrary dependencies. Existing sandboxing solutions — both "
    "agent-built-in and OS-level — fail to address this threat model: they protect files and secrets but cannot distinguish "
    "<i>terraform destroy</i> from <i>terraform plan</i>, or <i>npm install</i> from <i>npm list</i>. "
    "This whitepaper presents BlastShield, a two-layer defense architecture for macOS that combines kernel-level filesystem "
    "sandboxing (via Apple Seatbelt) with command-argument filtering (via biometric-authenticated PATH wrappers). We analyze "
    "why existing approaches are insufficient, describe the unique design decisions behind BlastShield — including protection "
    "against both cloud CLI destructive commands and package manager install commands — catalog remaining "
    "vulnerabilities, and identify areas for further research and empirical verification.",
    abstract_style,
))
story.append(Spacer(1, 12))
story.append(Paragraph(
    "<b>Keywords:</b> AI agent safety, cloud infrastructure protection, macOS sandbox-exec, Seatbelt, SBPL, "
    "command-argument filtering, defense in depth, supply chain protection, Terraform, Kubernetes, AWS, GCP, Azure, "
    "npm, pip, brew, package manager",
    ParagraphStyle("Keywords", parent=abstract_style, fontName="Times-Roman", fontSize=9, alignment=TA_LEFT),
))

story.append(PageBreak())

# 1. The Problem
story.append(Paragraph("1. The Problem", h1_style))
story.append(Paragraph(
    "AI coding agents — Claude Code, Codex, OpenCode, Cursor, and their peers — now operate with near-unrestricted "
    "access to developer machines. They read files, execute shell commands, and invoke cloud CLIs. The default deployment "
    "model trusts the agent entirely. When an agent runs with <font face='Courier' size='9'>--dangerously-skip-permissions</font>, "
    "<font face='Courier' size='9'>--full-auto</font>, or equivalent unrestricted modes, it can destroy production "
    "infrastructure in seconds.", body_style))
story.append(Paragraph(
    "The threat is not theoretical. A single <font face='Courier' size='9'>terraform destroy -auto-approve</font>, "
    "<font face='Courier' size='9'>gcloud compute instances delete</font>, <font face='Courier' size='9'>aws s3 rb --force</font>, "
    "or <font face='Courier' size='9'>kubectl delete namespace</font> issued by an autonomous agent — whether through "
    "misinterpretation, prompt injection, or hallucination — can cause irreversible damage. The blast radius is asymmetric: "
    "hours of human review versus seconds of automated execution.", body_style))
story.append(Paragraph(
    "Nor is the risk limited to cloud infrastructure. An autonomous agent can silently install new dependencies — "
    "<font face='Courier' size='9'>npm install</font>, <font face='Courier' size='9'>pip install</font>, "
    "<font face='Courier' size='9'>brew install</font>, <font face='Courier' size='9'>cargo add</font> — in seconds, "
    "introducing unvetted code into a project. A single malicious package added without review can compromise supply chain "
    "integrity, introduce vulnerabilities, or create subtle behavioral changes that are difficult to detect after the fact.", body_style))

# 2. Why Existing Solutions Don't Work
story.append(Paragraph("2. Why Existing Solutions Don't Work", h1_style))

story.append(Paragraph("2.1 Agent Built-in Sandboxes", h2_style))
story.append(Paragraph(
    "Most AI coding agents include their own sandbox or approval mechanism. Claude Code has <font face='Courier' size='9'>/sandbox</font> "
    "and confirmation prompts. Codex has approval policies. These operate at the <b>tool level</b> — they gate the agent's own "
    "tools and network access.", body_style))
story.append(Paragraph("Why they fail:", ParagraphStyle("WhyFail", parent=body_style, fontName="Times-Bold")))

for num, text in [
    ("1", "<b>Shell escape.</b> An agent that executes Bash or Python can run any subprocess. The agent's sandbox only sees its own tool calls, not the commands spawned by those tools. <font face='Courier' size='9'>bash -c \"terraform destroy -auto-approve\"</font> is invisible to the agent's permission system."),
    ("2", "<b>Opt-out culture.</b> The industry standard is <font face='Courier' size='9'>--dangerously-skip-permissions</font>. Developers disable safety mechanisms because they slow down workflows. Any protection that can be bypassed with a single flag will be bypassed."),
    ("3", "<b>Model-dependent.</b> Agent sandboxes rely on the LLM to follow instructions about what it should and shouldn't do. Prompt injection, jailbreaks, and simple hallucinations can cause the model to ignore its own constraints. Security that depends on a language model behaving correctly is not security."),
]:
    story.append(Paragraph(text, numbered_style, bulletText=f"{num}."))

story.append(Paragraph("2.2 Existing macOS Sandbox Tools", h2_style))
story.append(Paragraph(
    "Three open-source projects address AI agent sandboxing on macOS:", body_style))

story.append(make_table(
    ["Project", "Approach", "Focus"],
    [
        ["sandvault", "Separate macOS user account + sandbox-exec", "User isolation, file/secrets protection"],
        ["agent-safehouse", "Composable sandbox-exec profiles, Homebrew", "Filesystem policy, dotfile protection"],
        ["agent-seatbelt", "Two-file minimal sandbox-exec wrapper", "File/secrets protection"],
    ],
    [1.3 * inch, 2.3 * inch, 2.4 * inch],
))
story.append(Paragraph("Table 1: Existing macOS AI agent sandboxing tools.", caption_style))

story.append(Paragraph(
    "What they all share: a focus on protecting secrets and dotfiles. They prevent the agent from reading SSH keys, "
    "browser data, and shell history. This is valuable, but it addresses the wrong threat model for cloud infrastructure.", body_style))

story.append(Paragraph("Why they're insufficient:", ParagraphStyle("WhyFail2", parent=body_style, fontName="Times-Bold")))
for num, text in [
    ("1", "<b>No cloud CLI awareness.</b> None of them distinguish <i>terraform plan</i> from <i>terraform destroy</i>. The sandbox either allows the <i>terraform</i> binary entirely or blocks it entirely. There's no concept of destructive versus non-destructive subcommands."),
    ("2", "<b>No credential-path blocking.</b> Protecting <font face='Courier' size='9'>~/.ssh/</font> and <font face='Courier' size='9'>~/.bashrc</font> is necessary but not sufficient. Cloud CLIs authenticate through many paths — AWS credentials, Azure config, GCloud config, application-default credentials, SSO token caches, MSAL caches, Keychain entries. Existing tools don't systematically enumerate and block these credential paths for each cloud provider."),
    ("3", "<b>No state file protection.</b> Terraform state (<i>.tfstate</i>), Helm chart locks, CDK/SAM state — these are the objects that destructive operations mutate. Existing sandboxes don't protect them."),
    ("4", "<b>No command-argument filtering.</b> <font face='Courier' size='9'>sandbox-exec</font> operates at the file/process level. It cannot see command arguments. No existing tool addresses this gap with a second layer that filters by subcommand."),
    ("5", "<b>No install command blocking.</b> None of them prevent an agent from running <font face='Courier' size='9'>npm install</font>, <font face='Courier' size='9'>pip install</font>, <font face='Courier' size='9'>brew install</font>, or equivalent package manager commands. An agent can introduce arbitrary dependencies into a project in seconds — dependencies that may contain malicious code, introduce supply chain vulnerabilities, or subtly alter project behavior. Existing sandbox tools treat package managers as ordinary binaries, with no awareness that <i>install</i> subcommands are categorically different from <i>list</i> or <i>show</i>."),
]:
    story.append(Paragraph(text, numbered_style, bulletText=f"{num}."))

story.append(Paragraph("2.3 Container-Based Isolation", h2_style))
story.append(Paragraph(
    "Docker, Podman, and VM-based approaches provide strong isolation but at significant cost:", body_style))
for num, text in [
    ("1", "<b>Environment mismatch.</b> The agent operates in a container that doesn't match the developer's actual environment — different tools, different paths, different credentials. This defeats the purpose of an agent that's supposed to work <i>with</i> your infrastructure."),
    ("2", "<b>Credential passthrough.</b> To be useful, the container must receive cloud credentials. Mounting <font face='Courier' size='9'>~/.aws/</font> or passing <font face='Courier' size='9'>AWS_ACCESS_KEY_ID</font> gives the agent the same destructive capability, just in a different process namespace."),
    ("3", "<b>Workflow friction.</b> Running an agent inside a container adds setup complexity, volume management, and networking overhead that most developers won't tolerate for daily use."),
]:
    story.append(Paragraph(text, numbered_style, bulletText=f"{num}."))

# 3. The BlastShield Approach
story.append(Paragraph("3. The BlastShield Approach", h1_style))
story.append(Paragraph(
    "BlastShield introduces a two-layer defense architecture specifically designed for the cloud CLI destruction threat model.", body_style))

story.append(Paragraph("3.1 Layer 1: Kernel-Level Sandboxing (Hard Boundary)", h2_style))
story.append(Paragraph(
    "BlastShield uses macOS <font face='Courier' size='9'>sandbox-exec</font> (Apple Seatbelt) with carefully crafted "
    "SBPL profiles that:", body_style))
for bullet in [
    "<b>Block credential paths by provider.</b> Each cloud provider profile enumerates the specific credential, token cache, and authentication file paths for that provider. The agent process physically cannot read these files — the kernel enforces this regardless of what the agent tries.",
    "<b>Protect state files.</b> Terraform state, Helm chart locks, and backend configurations are write-protected. Even if the agent somehow authenticates, it cannot modify state.",
    "<b>Block global package directories and lockfiles.</b> The install profile denies writes to global package manager directories (node_modules globals, Homebrew Cellar, pip global site-packages, gem directories, Cargo registry, Hermit packages, apt/dnf package caches) and project lockfiles (package-lock.json, yarn.lock, pnpm-lock.yaml, Pipfile.lock, Gemfile.lock, Cargo.lock). The agent cannot install packages at the filesystem level.",
    "<b>Compose by intersection.</b> Profiles combine by intersecting their deny rules. Loading more profiles can only make the sandbox <i>more restrictive</i>, never less. This is a critical safety property — there's no accidental loosening.",
    "<b>Auto-detect from project.</b> BlastShield scans the project directory for indicator files (<font face='Courier' size='9'>*.tf</font>, <font face='Courier' size='9'>Chart.yaml</font>, <font face='Courier' size='9'>cdk.json</font>, <font face='Courier' size='9'>package.json</font>, <font face='Courier' size='9'>requirements.txt</font>, <font face='Courier' size='9'>Cargo.toml</font>, etc.) and automatically loads the appropriate profiles. Zero configuration for the common case.",
]:
    story.append(Paragraph(bullet, bullet_style, bulletText="•"))

story.append(Paragraph("3.2 Layer 2: Command-Argument Filtering (Speed Bump)", h2_style))
story.append(Paragraph(
    "Since <font face='Courier' size='9'>sandbox-exec</font> cannot distinguish <i>terraform destroy</i> from "
    "<i>terraform plan</i>, BlastShield adds a second layer:", body_style))
for bullet in [
    "<b>PATH wrappers.</b> <font face='Courier' size='9'>blastshield-guard install</font> creates wrapper scripts that intercept cloud CLI invocations before they reach the real binary.",
    "<b>Read-only by default.</b> Each wrapper classifies subcommands as read-only or mutating. Read-only commands (<font face='Courier' size='9'>plan</font>, <font face='Courier' size='9'>list</font>, <font face='Courier' size='9'>describe</font>, <font face='Courier' size='9'>get</font>) pass through immediately. Everything else requires authentication.",
    "<b>Install commands blocked.</b> Package manager install subcommands (<font face='Courier' size='9'>npm install</font>, <font face='Courier' size='9'>pip install</font>, <font face='Courier' size='9'>brew install</font>, <font face='Courier' size='9'>yarn add</font>, <font face='Courier' size='9'>pnpm add</font>, <font face='Courier' size='9'>gem install</font>, <font face='Courier' size='9'>cargo install</font>, <font face='Courier' size='9'>hermit install</font>, <font face='Courier' size='9'>apt install</font>, <font face='Courier' size='9'>dnf install</font>) are classified as mutating and require authentication. Read-only package operations (<font face='Courier' size='9'>npm list</font>, <font face='Courier' size='9'>pip show</font>, <font face='Courier' size='9'>brew info</font>, <font face='Courier' size='9'>cargo search</font>) pass through. This prevents the agent from arbitrarily adding dependencies without human review.",
    "<b>Biometric/password gate.</b> Mutating commands require <font face='Courier' size='9'>sudo</font> authentication, which on MacBooks triggers Touch ID or a password prompt. The agent cannot satisfy this — it requires a human.",
    "<b>Fresh auth each time.</b> <font face='Courier' size='9'>sudo -k</font> invalidates the timestamp before each check, ensuring that a previous successful authentication doesn't carry over.",
]:
    story.append(Paragraph(bullet, bullet_style, bulletText="•"))

story.append(Paragraph("3.3 Why This Combination Matters", h2_style))
story.append(Paragraph("Neither layer alone is sufficient. Table 2 illustrates the complementarity.", body_style))

story.append(make_table(
    ["Scenario", "Layer 1 (sandbox)", "Layer 2 (guard)"],
    [
        ["Agent reads ~/.aws/credentials directly", "✅ Blocked", "❌ Not visible"],
        ["Agent runs terraform destroy", "❌ Same binary as plan", "✅ Intercepted"],
        ["Agent uses full path to terraform destroy", "❌ Same binary", "❌ Bypassed"],
        ["Agent has credentials in env vars", "❌ Not file-based", "✅ Intercepted"],
        ["Agent runs npm install into global node_modules", "✅ Blocked (write denied)", "✅ Intercepted"],
        ["Agent runs pip install into project venv", "❌ Project writes allowed", "✅ Intercepted"],
        ["Agent writes package-lock.json directly", "✅ Blocked (lockfile write denied)", "❌ Not a CLI invocation"],
        ["Agent runs npm install via full path", "❌ Same binary", "❌ Bypassed, but lockfile blocked"],
    ],
    [2.8 * inch, 1.6 * inch, 1.6 * inch],
))
story.append(Paragraph("Table 2: Layer complementarity across attack scenarios.", caption_style))
story.append(Paragraph(
    "The layers are complementary. Layer 1 is the hard boundary that cannot be bypassed by clever command invocation. "
    "Layer 2 catches what Layer 1 cannot see — the <i>intent</i> of the command. For install protection specifically, "
    "Layer 1 prevents filesystem-level writes to global package directories and lockfiles, while Layer 2 catches "
    "project-local installs (e.g., <font face='Courier' size='9'>npm install</font> into <font face='Courier' size='9'>node_modules/</font>) "
    "that Layer 1 must allow because the base profile permits project writes.", body_style))

# 4. Unique Design Decisions
story.append(Paragraph("4. Unique Design Decisions", h1_style))

decisions = [
    ("4.1 Cloud CLI Focus, Not File Focus", "BlastShield inverts the existing tooling priority. Instead of \"protect all files, hope the agent doesn't run destructive commands,\" it asks: \"what specific operations would cause catastrophic damage, and how do we prevent those?\" The credential paths blocked are those that specifically enable cloud CLI authentication. The commands guarded are those that specifically destroy infrastructure."),
    ("4.2 Profile Intersection, Not Union", "When multiple profiles are loaded, their deny rules intersect. This means <font face='Courier' size='9'>blastshield -p terraform -p aws</font> is at least as restrictive as either profile alone. There is no possibility of two profiles accidentally creating an allow rule that neither intended."),
    ("4.3 Human-in-the-Loop for Mutations", "The guard layer enforces a principle: <b>the agent plans, you execute.</b> An agent can <font face='Courier' size='9'>terraform plan</font> and <font face='Courier' size='9'>aws describe-</font> all day. The moment it tries to mutate infrastructure, a human must be present. This aligns the security model with how infrastructure changes should work regardless of AI involvement."),
    ("4.4 Authentication as Authorization", "Rather than building a custom authorization system, BlastShield uses <font face='Courier' size='9'>sudo</font> as its authentication gate. This leverages macOS's existing biometric infrastructure (Touch ID) and PAM configuration. No new accounts, no new tokens, no new attack surface. The user's existing macOS authentication is the authorization."),
    ("4.5 Defense in Depth by Default", "The recommended setup includes both layers. But even Layer 1 alone provides meaningful protection — it blocks the credential reads that would enable destructive operations in the first place. The guard layer is the additional safety net for credentials that enter the process through other means (environment variables, credential helpers, Keychain)."),
    ("4.6 Supply Chain Protection as a First-Class Concern", "BlastShield extends the \"agent plans, you execute\" principle beyond infrastructure to dependency management. The install profile treats <font face='Courier' size='9'>npm install</font> with the same suspicion as <font face='Courier' size='9'>terraform apply</font> — both introduce changes that should be reviewed by a human before execution. This reflects a growing recognition that supply chain attacks through compromised packages are as dangerous as direct infrastructure destruction. The guard's read-only-by-default posture means agents can inspect existing dependencies (<font face='Courier' size='9'>npm list</font>, <font face='Courier' size='9'>pip show</font>, <font face='Courier' size='9'>brew info</font>) but cannot add new ones without human approval."),
]
for heading, text in decisions:
    story.append(Paragraph(heading, h2_style))
    story.append(Paragraph(text, body_style))

# 5. Remaining Vulnerabilities
story.append(Paragraph("5. Remaining Vulnerabilities", h1_style))
story.append(Paragraph(
    "BlastShield does not claim to be a complete solution. The following vulnerabilities remain.", body_style))

vulns = [
    ("5.1 Credential Exfiltration via Network", "High",
     "The sandbox allows network access because agents need it (API calls, package downloads, git operations). If a credential enters the process through an allowed path — an environment variable without <font face='Courier' size='9'>-c</font>, a credential helper response, or a Keychain entry — the agent can exfiltrate it over the network.",
     "Use <font face='Courier' size='9'>-c</font> / <font face='Courier' size='9'>--clean-env</font> to strip API keys from environment variables. For credential helpers, there is no current mitigation — this is a fundamental limitation of file-path-based sandboxing.",
     "Network-level filtering that distinguishes legitimate API calls from exfiltration. Possible approaches include egress proxies with allowlisted domains, DNS-level filtering, or <font face='Courier' size='9'>sandbox-exec</font>'s network rules (which would break most agent workflows)."),
    ("5.2 Keychain Access", "Medium",
     "Keychain access is allowed so that credential helpers work (e.g., <font face='Courier' size='9'>aws</font> CLI using Keychain as its credential store). An agent can perform authenticated actions via credential helpers — <font face='Courier' size='9'>git push</font>, <font face='Courier' size='9'>aws s3 ls</font> — but cannot read raw tokens from files. The agent can <i>act</i> on your behalf but cannot <i>steal</i> your credentials.",
     "None currently without breaking legitimate workflows. A future approach could restrict Keychain access to specific service entries rather than blanket allow.",
     "Fine-grained Keychain access control via <font face='Courier' size='9'>security</font> CLI or <font face='Courier' size='9'>sandbox-exec</font> Keychain rules."),
    ("5.3 PATH Wrapper Bypass", "Medium",
     "Layer 2 (guard) is explicitly a speed bump, not a hard boundary. A determined agent that specifies the full path to a CLI (<font face='Courier' size='9'>/usr/local/bin/terraform destroy</font>) bypasses PATH wrappers.",
     "Layer 1 (sandbox) is the hard boundary. Even with the guard bypassed, the agent cannot read credentials. The guard catches accidental and casual misuse; Layer 1 catches everything else.",
     "Binary-level argument filtering that doesn't depend on PATH ordering. Possible approaches include <font face='Courier' size='9'>DYLD_INSERT_LIBRARIES</font> to intercept <font face='Courier' size='9'>exec*</font> calls, or macOS Endpoint Security Framework monitoring — though both have significant complexity and stability trade-offs."),
    ("5.4 Environment Variable Secrets", "Medium",
     "Without <font face='Courier' size='9'>-c</font>, secrets in environment variables (<font face='Courier' size='9'>AWS_ACCESS_KEY_ID</font>, <font face='Courier' size='9'>GOOGLE_APPLICATION_CREDENTIALS</font> content, etc.) are readable by the agent. The sandbox operates on file paths, not process memory.",
     "Always use <font face='Courier' size='9'>-c</font> / <font face='Courier' size='9'>--clean-env</font>. Add <font face='Courier' size='9'>blastshield -c</font> to your agent launch commands.",
     "Automatic detection and stripping of cloud-related environment variables without requiring the <font face='Courier' size='9'>-c</font> flag."),
    ("5.5 sandbox-exec Deprecation", "Long-term",
     "Apple deprecated the <font face='Courier' size='9'>sandbox-exec</font> command-line interface in macOS 10.15 Catalina. It still works on macOS Sequoia (15.x), but Apple provides no guarantee of future support.",
     "None currently. There is no Apple-provided replacement for ad-hoc CLI sandboxing.",
     "Monitor Apple's frameworks for a replacement API (possibly based on Endpoint Security Framework or improved entitlement-based sandboxing). Develop a bubblewrap/Firejail backend for Linux. Evaluate whether Endpoint Security Framework can replicate the file-path deny rules."),
    ("5.6 Nested Sandbox Limitation", "Low",
     "macOS does not support recursive <font face='Courier' size='9'>sandbox-exec</font>. If the agent process is already running inside a sandbox (e.g., a sandboxed app), BlastShield's Layer 1 cannot be applied.",
     "Use Layer 2 (guard) alone in nested environments. Restructure setups to use a single <font face='Courier' size='9'>sandbox-exec</font> layer.",
     "Determine whether Endpoint Security Framework or <font face='Courier' size='9'>DYLD_INSERT_LIBRARIES</font> approach can provide equivalent file-path protection without conflicting with an existing sandbox."),
    ("5.7 Content-Level Filtering Impossibility", "Low",
     "<font face='Courier' size='9'>sandbox-exec</font> operates on file paths, not file contents. It cannot prevent an agent from reading a file that's allowed by path but contains secrets in its content. It also cannot prevent an agent from writing destructive content to an allowed file path.",
     "This is a fundamental limitation of OS-level path-based sandboxing. There is no mitigation within the BlastShield model.",
     "Content-aware file access monitoring (possibly via Endpoint Security Framework or FSEvents), though this would add significant performance overhead."),
    ("5.8 Agent-Specific Prompt Injection", "Unknown",
     "A malicious input (file content, web page, API response) could cause the agent to attempt destructive operations. BlastShield mitigates the <i>execution</i> of such operations but cannot prevent the <i>attempt</i>.",
     "Layers 1 and 2 together make execution unlikely but not impossible (see credential exfiltration and PATH bypass above).",
     "Integration with agent-level content filtering or guardrail systems that detect and reject prompt injection attempts before they reach the agent's reasoning."),
    ("5.9 Package Manager Evasion Techniques", "Medium",
     "The install guard protects against standard package manager invocations, but several bypass vectors exist. Agents can invoke package managers through scripting language package managers not yet guarded (e.g., <font face='Courier' size='9'>luarocks install</font>, <font face='Courier' size='9'>nix-env -i</font>, <font face='Courier' size='9'>conda install</font>). They can also install packages by downloading and executing install scripts directly (<font face='Courier' size='9'>curl | bash</font>), or by modifying configuration files that trigger package installation on the next build.",
     "Layer 1 blocks writes to lockfiles and global package directories, catching many bypass attempts. The guard covers the most common package managers (npm, yarn, pnpm, pip, brew, gem, cargo, hermit, apt, dnf). Less common managers can be added as demand warrants.",
     "Heuristic detection of install-like behavior regardless of the specific tool used — for example, detecting writes to known package directories even when the writing process is not a recognized package manager binary."),
]

for heading, severity, description, mitigation, research in vulns:
    story.append(Paragraph(heading, h2_style))
    story.append(sev(severity))
    story.append(Paragraph(description, body_style))
    story.append(Paragraph("<b>Mitigation:</b> " + mitigation, body_style))
    story.append(Paragraph("<b>Research needed:</b> " + research, body_style))

story.append(make_table(
    ["Vulnerability", "Severity"],
    [[v[0].replace("5.", ""), v[1]] for v in vulns],
    [4.5 * inch, 1.5 * inch],
))
story.append(Paragraph("Table 3: Summary of remaining vulnerabilities.", caption_style))

# 6. Areas for Further Research
story.append(Paragraph("6. Areas for Further Research and Verification", h1_style))

research_areas = [
    ("6.1 Empirical Effectiveness Testing", [
        "<b>Fuzz testing.</b> Generate random subcommand combinations for each CLI and verify that read-only commands pass and mutating commands are blocked.",
        "<b>Real-world audit.</b> Run actual agent workflows (Terraform deploy, Kubernetes management, AWS operations) inside BlastShield and verify that no destructive operation succeeds without authentication.",
        "<b>Regression testing.</b> Cloud CLIs add new subcommands in every release. The guard patterns need continuous validation against new CLI versions.",
    ]),
    ("6.2 Cross-Platform Portability", [
        "<b>Linux (bubblewrap/Firejail).</b> Namespace-based sandboxing can replicate most <font face='Courier' size='9'>sandbox-exec</font> capabilities. Profile translation from SBPL to bubblewrap arguments is feasible.",
        "<b>Windows (AppContainer).</b> Windows has its own sandboxing primitives (AppContainer, MIC) that could support a similar model.",
    ]),
    ("6.3 Formal Verification of Profile Composition", [
        "The profile intersection property (\"loading more profiles can only make the sandbox more restrictive\") should be formally verified. If two profiles contain conflicting allow rules, the intersection must still deny access. This requires a formal model of SBPL semantics and a proof that the composition operator is monotonic with respect to restriction.",
    ]),
    ("6.4 Integration with CI/CD Pipelines", [
        "AI agents increasingly run in CI/CD pipelines (GitHub Actions, GitLab CI) where the same destructive capabilities exist. Adapting BlastShield's concepts to container-based CI environments — where <font face='Courier' size='9'>sandbox-exec</font> is unavailable — would require a different enforcement mechanism (seccomp, AppArmor, or pipeline-level permissions).",
    ]),
    ("6.5 Credential Helper Protocol Analysis", [
        "The interaction between cloud CLIs and credential helpers (Keychain, <font face='Courier' size='9'>aws-sso-util</font>, <font face='Courier' size='9'>gcloud auth</font>, <font face='Courier' size='9'>az login</font>) needs deeper analysis. Understanding exactly which Keychain entries and IPC channels each helper uses would enable fine-grained allowlisting instead of the current blanket Keychain allow.",
    ]),
    ("6.6 Agent Telemetry and Anomaly Detection", [
        "Monitoring agent behavior inside the sandbox could provide early warning of attempted breaches: log sandbox violations (already supported via <font face='Courier' size='9'>--violations</font>), track unusual command patterns (e.g., an agent attempting multiple destructive commands in sequence), and alert on credential access attempts that were blocked. This telemetry could feed into a real-time risk scoring system that escalates to the user before a breach attempt succeeds.",
    ]),
    ("6.7 Supply Chain Attack Surface Analysis", [
        "The install profile protects against the most common package managers, but the supply chain attack surface is broader than direct package installation. Further research is needed on:",
        "<b>Transitive dependency risk.</b> An agent that modifies <font face='Courier' size='9'>package.json</font> or <font face='Courier' size='9'>requirements.txt</font> directly (adding entries rather than running <font face='Courier' size='9'>npm install</font>) introduces dependencies that will be installed on the next <font face='Courier' size='9'>npm ci</font> or <font face='Courier' size='9'>pip install -r</font>. BlastShield's lockfile protection catches this in projects that commit lockfiles, but projects without lockfiles remain vulnerable.",
        "<b>Language-specific package managers.</b> The current guard covers 10 package managers, but many more exist (conda, nix, guix, luarocks, cpanm, cabal, stack, opam, vcpkg, nuget). A systematic survey of which package managers AI agents commonly invoke would help prioritize additional guard coverage.",
        "<b>Install script detection.</b> Many packages recommend installation via <font face='Courier' size='9'>curl | bash</font> or <font face='Courier' size='9'>wget | sh</font> patterns. Detecting and blocking these patterns requires content-level analysis (reading the command arguments), which is within the guard's capability but not yet implemented.",
    ]),
]

for heading, items in research_areas:
    story.append(Paragraph(heading, h2_style))
    for item in items:
        story.append(Paragraph(item, bullet_style, bulletText="•"))

# 7. Conclusion
story.append(Paragraph("7. Conclusion", h1_style))
story.append(Paragraph(
    "BlastShield addresses a specific, high-severity gap in AI agent safety: preventing autonomous destruction of cloud "
    "infrastructure and arbitrary installation of unvetted dependencies. It does this through a two-layer architecture — "
    "kernel-level file sandboxing plus command-argument filtering — that existing tools do not provide.", body_style))
story.append(Paragraph(
    "The approach is pragmatic: it uses macOS's built-in sandboxing primitives rather than building new infrastructure, "
    "it composes with existing tools rather than replacing them, and it acknowledges its own limitations rather than "
    "claiming false security. By extending protection from cloud CLI destructive commands to package manager install "
    "commands, BlastShield recognizes that supply chain integrity is as critical as infrastructure integrity in an "
    "agentic engineering workflow.", body_style))
story.append(Paragraph(
    "The remaining vulnerabilities are real. Credential exfiltration via network, Keychain access, "
    "<font face='Courier' size='9'>sandbox-exec</font> deprecation, and package manager evasion techniques are open "
    "problems that require further research. But the current state — AI agents with unrestricted access to production "
    "cloud credentials and package managers — is strictly worse. BlastShield makes the threat model narrower and the "
    "blast radius smaller. That's worth something.", body_style))

# References
story.append(Paragraph("References", h1_style))
refs = [
    "Apple Inc. (2011). <i>Apple Sandbox Guide v1.0</i>. https://reverse.put.as/wp-content/uploads/2011/09/Apple-Sandbox-Guide-v1.0.pdf",
    "sandvault: https://github.com/webcoyote/sandvault",
    "agent-safehouse: https://github.com/eugene1g/agent-safehouse",
    "agent-seatbelt: https://github.com/CJHwong/agent-seatbelt",
    "bubblewrap: https://github.com/containers/bubblewrap",
    "BlastShield: https://github.com/cdrxyz/blastshield",
]
ref_style = ParagraphStyle("Ref", parent=body_style, fontSize=9, leading=13, leftIndent=24, firstLineIndent=-24, spaceAfter=4)
for i, ref in enumerate(refs, 1):
    story.append(Paragraph(f"[{i}] {ref}", ref_style))

# Build
doc.build(story)
print(f"PDF generated: {OUTPUT_FILE}")
