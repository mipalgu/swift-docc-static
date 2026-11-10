#!/usr/bin/env node
// Exits with status 0 if the visual regression harness can run on this machine:
// playwright-core can be loaded and a browser can be launched.  The Swift browser tests
// use this to decide whether to run or skip.
import { launchBrowser, loadPlaywright } from './lib/playwright.mjs';

if (!loadPlaywright()) process.exit(1);
try {
  const browser = await launchBrowser();
  await browser.close();
} catch {
  process.exit(1);
}
