const fs = require("fs");
const path = require("path");
const sharp = require("sharp");

const ROOT = __dirname;
const RAW = path.join(ROOT, "raw");
const GENERATED = path.join(ROOT, "generated");
const FINAL = path.join(ROOT, "final", "candidates");
const TOP = path.join(ROOT, "final", "top-10");
const COMPOSITION_WIDTH = 1320;
const COMPOSITION_HEIGHT = 2868;
const EXPORT_WIDTH = 1284;
const EXPORT_HEIGHT = 2778;
const SIMULATOR_IPHONE = path.join(
  RAW,
  "simulator-window-iphone17promax.jpeg"
);
const LOGO = path.join(
  ROOT,
  "..",
  "Salom-Ai-iOS",
  "Salom-Ai-iOS",
  "Resources",
  "Assets.xcassets",
  "AppIcon.appiconset",
  "ChatGPT Image Nov 11, 2025, 06_23_19 PM.png"
);

fs.mkdirSync(FINAL, { recursive: true });
fs.mkdirSync(TOP, { recursive: true });

const shots = [
  {
    id: "01",
    slug: "search",
    raw: "01-chat-search.png",
    bg: "01-hero-bg-v2.png",
    headline: ["O‘zbekcha AI.", "Har kuni yoningizda."],
    support: "Savol, rasm va hujjat — bitta ilovada",
    dark: true,
    width: 920,
    angle: 0,
    x: 150,
    y: 875,
    alignX: 64,
    top: true,
  },
  {
    id: "02",
    slug: "image-editing",
    raw: "02-image-reference-composer.png",
    bg: "02-image-bg.png",
    headline: ["Rasm yuboring.", "Natijani ayting."],
    support: "Bir nechta rasmni birga tahrirlang",
    dark: true,
    width: 1010,
    angle: -3.5,
    x: 165,
    y: 650,
    top: true,
  },
  {
    id: "03",
    slug: "work-writing",
    raw: "03-chat-work-document.png",
    bg: "03-work-bg.png",
    headline: ["Ish uchun", "tayyor matnlar"],
    support: "Taklif, hisobot va rasmiy xat",
    dark: false,
    width: 1030,
    angle: 0,
    x: 145,
    y: 675,
    top: true,
  },
  {
    id: "04",
    slug: "apps-hub",
    raw: "04-apps-hub.png",
    bg: "04-apps-bg.png",
    headline: ["Bitta ilova.", "O‘nlab vositalar."],
    support: "O‘qish, ish va kundalik hayot uchun",
    dark: true,
    width: 1050,
    angle: 2.5,
    x: 130,
    y: 665,
    top: true,
  },
  {
    id: "05",
    slug: "dtm",
    raw: "05-dtm-tests.png",
    bg: "05-dtm-bg.png",
    headline: ["DTMga har kuni", "tayyorlaning"],
    support: "8 fan va yuzlab savollar",
    dark: true,
    width: 1080,
    angle: 0,
    x: 120,
    y: 675,
    top: true,
  },
  {
    id: "06",
    slug: "presentations",
    raw: "06-presentations.png",
    bg: "06-presentations-bg.png",
    headline: ["Taqdimot —", "bir necha daqiqada"],
    support: "PPTX va PDF formatida",
    dark: false,
    width: 1090,
    angle: -6,
    x: 300,
    y: 700,
    top: true,
  },
  {
    id: "07",
    slug: "referats",
    raw: "07-referats.png",
    bg: "07-referats-bg.png",
    headline: ["Referat va insho", "tayyor"],
    support: "Mavzuni kiriting, hujjatni oling",
    dark: false,
    width: 1090,
    angle: 6,
    x: -170,
    y: 700,
    top: true,
  },
  {
    id: "08",
    slug: "work-documents",
    raw: "08-work-documents.png",
    bg: "08-work-documents-bg.png",
    headline: ["Hujjatlar siz", "uchun ishlasin"],
    support: "Shartnoma, taklif va hisobot",
    dark: true,
    width: 1040,
    angle: 0,
    x: 140,
    y: 675,
    top: true,
  },
  {
    id: "09",
    slug: "voice",
    raw: "09-voice-chat.png",
    bg: "09-voice-bg.png",
    headline: ["Gapiring.", "Salom AI tinglaydi."],
    support: "O‘zbekcha tabiiy ovozli suhbat",
    dark: true,
    width: 980,
    angle: 0,
    x: 170,
    y: 675,
    top: true,
  },
  {
    id: "10",
    slug: "government",
    raw: "10-government-guide.png",
    bg: "10-government-bg.png",
    headline: ["Davlat xizmatlarini", "oson toping"],
    support: "Faqat rasmiy manbalar bilan",
    dark: false,
    width: 1020,
    angle: -3,
    x: 165,
    y: 675,
    top: true,
  },
  {
    id: "11",
    slug: "salary",
    raw: "11-salary-calculator.png",
    bg: "11-salary-bg.png",
    headline: ["Sof maoshingizni", "hisoblang"],
    support: "Brutto, netto va mehnat ma’lumoti",
    dark: false,
    width: 1020,
    angle: 3,
    x: 135,
    y: 675,
  },
  {
    id: "12",
    slug: "teacher",
    raw: "12-teacher-assistant.png",
    bg: "12-teacher-bg.png",
    headline: ["Darsga tezroq", "tayyorlaning"],
    support: "Reja, test va ota-onaga hisobot",
    dark: true,
    width: 1020,
    angle: -4,
    x: 165,
    y: 675,
  },
  {
    id: "13",
    slug: "document",
    raw: "13-document-explainer.png",
    bg: "13-document-bg.png",
    headline: ["Murakkab hujjatni", "sodda tushuning"],
    support: "PDF va rasmdagi muhim joylar",
    dark: true,
    width: 1020,
    angle: 4,
    x: 120,
    y: 675,
  },
  {
    id: "14",
    slug: "marketplace",
    raw: "14-marketplace-seller.png",
    bg: "14-marketplace-bg.png",
    headline: ["Mahsulotingizni", "yaxshiroq soting"],
    support: "Kartochka, narx va savdo rejasi",
    dark: true,
    width: 1030,
    angle: -2,
    x: 155,
    y: 675,
  },
  {
    id: "15",
    slug: "budget",
    raw: "15-family-budget.png",
    bg: "15-budget-bg.png",
    headline: ["Pulni reja bilan", "boshqaring"],
    support: "Byudjet, qarz va jamg‘arma",
    dark: false,
    width: 1030,
    angle: 0,
    x: 145,
    y: 675,
  },
];

const escapeXml = (value) =>
  value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");

async function roundImage(image, width, height, radius) {
  const mask = Buffer.from(
    `<svg width="${width}" height="${height}">
      <rect x="0" y="0" width="${width}" height="${height}" rx="${radius}" ry="${radius}" fill="white"/>
    </svg>`
  );
  return image
    .composite([{ input: mask, blend: "dest-in" }])
    .png()
    .toBuffer();
}

async function simulatorHardwareOverlay() {
  const crop = { left: 8, top: 56, width: 467, height: 972 };
  const { data, info } = await sharp(SIMULATOR_IPHONE)
    .extract(crop)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });

  for (let offset = 0; offset < data.length; offset += info.channels) {
    const average = (data[offset] + data[offset + 1] + data[offset + 2]) / 3;
    data[offset + 3] = Math.max(0, Math.min(255, Math.round((255 - average) * 4)));
  }

  const hole = Buffer.from(
    `<svg width="${crop.width}" height="${crop.height}">
      <rect x="19" y="23" width="429" height="933" rx="45" ry="45" fill="white"/>
    </svg>`
  );

  return sharp(data, {
    raw: {
      width: info.width,
      height: info.height,
      channels: info.channels,
    },
  })
    .composite([{ input: hole, blend: "dest-out" }])
    .png()
    .toBuffer();
}

async function makeIPhoneHardware(rawPath, width) {
  const screenWidth = 429;
  const screenHeight = 933;
  const screen = await sharp(rawPath)
    .resize(screenWidth, screenHeight, { fit: "fill" })
    .png()
    .toBuffer();
  const roundedScreen = await roundImage(
    sharp(screen),
    screenWidth,
    screenHeight,
    45
  );
  const hardware = await simulatorHardwareOverlay();
  const device = await sharp({
    create: {
      width: 467,
      height: 972,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    },
  })
    .composite([
      { input: roundedScreen, left: 19, top: 23 },
      { input: hardware, left: 0, top: 0 },
    ])
    .png()
    .toBuffer();

  return sharp(device)
    .resize({ width, kernel: sharp.kernel.lanczos3 })
    .sharpen({ sigma: 0.55 })
    .png()
    .toBuffer();
}

async function clippedPlacement(
  input,
  left,
  top,
  canvasWidth = COMPOSITION_WIDTH,
  canvasHeight = COMPOSITION_HEIGHT
) {
  const metadata = await sharp(input).metadata();
  const sourceLeft = Math.max(0, -left);
  const sourceTop = Math.max(0, -top);
  const targetLeft = Math.max(0, left);
  const targetTop = Math.max(0, top);
  const width = Math.min(
    metadata.width - sourceLeft,
    canvasWidth - targetLeft
  );
  const height = Math.min(
    metadata.height - sourceTop,
    canvasHeight - targetTop
  );

  if (width <= 0 || height <= 0) {
    throw new Error(`Overlay is outside the canvas: ${left},${top}`);
  }

  const clipped = await sharp(input)
    .extract({
      left: sourceLeft,
      top: sourceTop,
      width,
      height,
    })
    .png()
    .toBuffer();

  return { input: clipped, left: targetLeft, top: targetTop };
}

function typographySvg(shot) {
  const titleColor = shot.dark ? "#FFFFFF" : "#0B1633";
  const supportColor = shot.dark ? "#C4CCDD" : "#667085";
  const brandColor = shot.dark ? "#E8F7FF" : "#11213D";
  const line1 = escapeXml(shot.headline[0]);
  const line2 = escapeXml(shot.headline[1] || "");
  const support = escapeXml(shot.support);
  return Buffer.from(
    `<svg width="1320" height="620" xmlns="http://www.w3.org/2000/svg">
      <style>
        .brand { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", Arial, sans-serif; font-size: 30px; font-weight: 800; letter-spacing: 4px; fill: ${brandColor}; }
        .title { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", Arial, sans-serif; font-size: 84px; font-weight: 800; letter-spacing: -2px; fill: ${titleColor}; }
        .support { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", Arial, sans-serif; font-size: 37px; font-weight: 560; fill: ${supportColor}; }
      </style>
      <text x="178" y="142" class="brand">SALOM AI</text>
      <rect x="82" y="228" width="72" height="9" rx="4.5" fill="#48BFF6"/>
      <rect x="154" y="228" width="30" height="9" rx="4.5" fill="#8B5CF6"/>
      <text x="82" y="330" class="title">
        <tspan x="82" dy="0">${line1}</tspan>
        <tspan x="82" dy="94">${line2}</tspan>
      </text>
      <text x="82" y="540" class="support">${support}</text>
    </svg>`
  );
}

async function makeShot(shot) {
  const background = await sharp(path.join(GENERATED, shot.bg))
    .resize(COMPOSITION_WIDTH, COMPOSITION_HEIGHT, { fit: "cover" })
    .modulate({ saturation: shot.dark ? 0.92 : 0.82 })
    .png()
    .toBuffer();

  const phone = await makeIPhoneHardware(path.join(RAW, shot.raw), shot.width);
  const phoneMeta = await sharp(phone).metadata();
  const centeredX = Math.round((COMPOSITION_WIDTH - phoneMeta.width) / 2);
  const safeX = Math.max(
    0,
    Math.min(
      shot.alignX ?? centeredX,
      COMPOSITION_WIDTH - phoneMeta.width
    )
  );
  const safeY = Math.round(
    Math.min(shot.y, COMPOSITION_HEIGHT - phoneMeta.height - 24)
  );

  const logo = await sharp(LOGO)
    .resize(74, 74, { fit: "cover" })
    .png()
    .toBuffer();
  const roundedLogo = await roundImage(sharp(logo), 74, 74, 18);
  const phonePlacement = await clippedPlacement(phone, safeX, safeY);

  const output = path.join(FINAL, `${shot.id}-${shot.slug}.png`);
  const composition = await sharp(background)
    .composite([
      phonePlacement,
      { input: typographySvg(shot), left: 0, top: 0 },
      { input: roundedLogo, left: 82, top: 88 },
    ])
    .removeAlpha()
    .png()
    .toBuffer();

  await sharp(composition)
    .resize(EXPORT_WIDTH, EXPORT_HEIGHT, {
      fit: "cover",
      position: "centre",
      kernel: sharp.kernel.lanczos3,
    })
    .removeAlpha()
    .png({ compressionLevel: 9 })
    .toFile(output);

  if (shot.top) {
    fs.copyFileSync(output, path.join(TOP, path.basename(output)));
  }
}

(async () => {
  for (const shot of shots) {
    await makeShot(shot);
    process.stdout.write(`created ${shot.id}-${shot.slug}\n`);
  }
})();
