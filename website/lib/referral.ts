export const REFERRAL_CAP = 12;
export const REFERRAL_REWARD_DAYS = 7;
export const REFERRED_TRIAL_DAYS = 14;

const ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"; // no 0/O/1/I

export function generateReferralCode(): string {
  let code = "";
  for (let i = 0; i < 6; i++) {
    code += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
  }
  return `EZ-${code}`;
}
