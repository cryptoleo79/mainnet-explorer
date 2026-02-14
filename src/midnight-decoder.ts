/**
 * Midnight Transaction Decoder
 * Parses sendMnTransaction args to extract readable data
 */

interface DecodedTransaction {
  version: string;
  signatureType: string;
  proofType: string;
  rawHeader: string;
  identifiers: string[];
  contractAddresses: string[];
  transactionType?: string;
}

export function decodeMidnightTransaction(argsJson: string): DecodedTransaction | null {
  try {
    const args = JSON.parse(argsJson);
    if (!Array.isArray(args) || args.length === 0) return null;
    
    let hexData = args[0];
    if (typeof hexData !== 'string') return null;
    if (hexData.startsWith('0x')) hexData = hexData.slice(2);
    
    // Decode hex to find header
    const decoded = Buffer.from(hexData, 'hex').toString('utf8');
    
    // Check for midnight:transaction header
    let version = 'unknown';
    let signatureType = 'unknown';
    let proofType = 'unknown';
    let rawHeader = '';
    
    if (decoded.startsWith('midnight:transaction')) {
      // Extract version: midnight:transaction[v6]
      const versionMatch = decoded.match(/midnight:transaction\[v(\d+)\]/);
      if (versionMatch) {
        version = `v${versionMatch[1]}`;
      }
      
      // Extract signature and proof types
      const typesMatch = decoded.match(/\(signature\[v(\d+)\],([^,]+),([^)]+)\)/);
      if (typesMatch) {
        signatureType = `v${typesMatch[1]}`;
        proofType = typesMatch[3];
      }
      
      // Get the full header up to the colon after the closing paren
      const headerEnd = decoded.indexOf('):');
      if (headerEnd > 0) {
        rawHeader = decoded.slice(0, headerEnd + 2);
      }
    }
    
    // Extract unique 32-byte identifiers
    const identifiers = extractIdentifiers(hexData);
    
    return {
      version,
      signatureType,
      proofType,
      rawHeader: rawHeader || decoded.slice(0, 80),
      identifiers: identifiers.slice(0, 10), // First 10
      contractAddresses: [],
      transactionType: detectType(decoded)
    };
  } catch (e) {
    return null;
  }
}

function extractIdentifiers(hexData: string): string[] {
  const ids: string[] = [];
  const matches = hexData.match(/[0-9a-f]{64}/gi) || [];
  
  for (const m of matches) {
    // Skip all zeros or repetitive patterns
    if (!/^0+$/.test(m) && !/^(.)\1+$/.test(m)) {
      const formatted = '0x' + m;
      if (!ids.includes(formatted)) ids.push(formatted);
    }
  }
  return ids;
}

function detectType(decoded: string): string {
  if (decoded.includes('check_balance')) return 'balance_check';
  if (decoded.includes('transfer')) return 'transfer';
  if (decoded.includes('deploy')) return 'contract_deploy';
  return 'transaction';
}
