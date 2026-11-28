// Firestore security rules tests, on the local emulator with a demo
// project ID, so they never touch the live project:
//   cd tool/rules_test && npm ci && npm test
// `npm test` starts the emulator, runs this file and stops it. Needs
// Java 21 or newer. CI runs it in the firestore-rules job.
//
// Each write below is the exact shape the app sends (see the Dart
// repositories), so a rules change that would refuse a real write fails
// here first.
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
  arrayUnion,
  writeBatch,
} from 'firebase/firestore';

const NOW = '2026-11-26T09:00:00.000Z';
let env;

const company = {
  id: 'c1',
  name: 'Firm',
  country: 'LKA',
  annualTurnover: 850000,
  currency: 'EUR',
  teamSize: 4,
  ownerUid: 'owner',
  members: { owner: 'owner', bm: 'bid_manager' },
  memberEmails: { owner: 'owner@firm.test', bm: 'bm@firm.test' },
};

const otherCompany = {
  ...company,
  id: 'c2',
  name: 'Other',
  ownerUid: 'rival',
  members: { rival: 'owner' },
  memberEmails: { rival: 'rival@other.test' },
};

/** A bid as BidWorkflow.watch writes it. */
function bid(overrides = {}) {
  return {
    id: 'c1_ted_1',
    tenderId: 'ted_1',
    companyId: 'c1',
    stage: 'watching',
    ownerUid: 'bm',
    title: 'Hospital system',
    buyer: 'Ministry',
    deadline: '2026-12-20T00:00:00.000Z',
    verdict: 'BID',
    fitScore: 80,
    approval: 'none',
    approvalNote: '',
    requestedBy: null,
    tasks: [],
    taskDone: {},
    lossReasons: [],
    createdAt: NOW,
    updatedAt: NOW,
    ...overrides,
  };
}

const checklist = [
  { id: 't0', title: 'Price the offer', assigneeUid: null, done: false },
  { id: 't1', title: 'Submit', assigneeUid: null, done: false },
];

const approvedBid = (overrides = {}) =>
  bid({
    stage: 'preparing',
    approval: 'approved',
    approvalNote: 'Go',
    requestedBy: 'bm',
    tasks: checklist,
    ...overrides,
  });

function as(uid, token = {}) {
  const email = `${uid}@firm.test`;
  return env
    .authenticatedContext(uid, { email, email_verified: true, ...token })
    .firestore();
}

const owner = () => as('owner');
const manager = () => as('bm');
const stranger = () => as('stranger');

async function seed(docs) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [path, data] of Object.entries(docs)) {
      await setDoc(doc(db, path), data);
    }
  });
}

/** Reads [path] with the rules off and returns pick(data), or null. */
async function read(path, pick = (d) => d) {
  let out = null;
  await env.withSecurityRulesDisabled(async (ctx) => {
    const snap = await getDoc(doc(ctx.firestore(), path));
    out = snap.exists() ? pick(snap.data()) : null;
  });
  return out;
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-bidradar',
    firestore: {
      rules: readFileSync(
        new URL('../../firestore.rules', import.meta.url),
        'utf8',
      ),
    },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seed({ 'companies/c1': company, 'companies/c2': otherCompany });
});

describe('bids: create', () => {
  test('a member starts watching a tender', async () => {
    await assertSucceeds(setDoc(doc(manager(), 'bids/c1_ted_1'), bid()));
  });

  test('a bid manager may ask for approval while creating', async () => {
    await assertSucceeds(
      setDoc(
        doc(manager(), 'bids/c1_ted_1'),
        bid({ approval: 'pending', requestedBy: 'bm' }),
      ),
    );
  });

  test('a bid manager cannot create an approved bid', async () => {
    await assertFails(
      setDoc(doc(manager(), 'bids/c1_ted_1'), approvedBid({ tasks: [] })),
    );
    await assertFails(
      setDoc(doc(manager(), 'bids/c1_ted_1'), bid({ approval: 'approved' })),
    );
    await assertFails(
      setDoc(doc(manager(), 'bids/c1_ted_1'), bid({ stage: 'won' })),
    );
  });

  test('a new bid has no owner note, checklist or outcome', async () => {
    const db = manager();
    await assertFails(
      setDoc(doc(db, 'bids/c1_ted_1'), bid({ approvalNote: 'ok' })),
    );
    await assertFails(setDoc(doc(db, 'bids/c1_ted_1'), bid({ tasks: checklist })));
    await assertFails(
      setDoc(doc(db, 'bids/c1_ted_1'), bid({ lossReasons: ['Other'] })),
    );
  });

  test('the bid ID belongs to the company and the creator', async () => {
    await assertFails(setDoc(doc(manager(), 'bids/c2_ted_1'), bid()));
    await assertFails(
      setDoc(doc(manager(), 'bids/c1_ted_1'), bid({ ownerUid: 'owner' })),
    );
    await assertFails(
      setDoc(
        doc(manager(), 'bids/c1_ted_1'),
        bid({ approval: 'pending', requestedBy: 'owner' }),
      ),
    );
  });

  test('a stranger cannot create or read bids', async () => {
    await assertFails(setDoc(doc(stranger(), 'bids/c1_ted_1'), bid()));
    await seed({ 'bids/c1_ted_1': bid() });
    await assertFails(getDoc(doc(stranger(), 'bids/c1_ted_1')));
  });
});

describe('bids: bid manager updates', () => {
  test('asks for approval from none or rejected', async () => {
    await seed({ 'bids/c1_ted_1': bid() });
    await assertSucceeds(
      updateDoc(doc(manager(), 'bids/c1_ted_1'), {
        approval: 'pending',
        requestedBy: 'bm',
        updatedAt: NOW,
      }),
    );
    await seed({
      'bids/c1_ted_1': bid({ approval: 'rejected', approvalNote: 'No' }),
    });
    await assertSucceeds(
      updateDoc(doc(manager(), 'bids/c1_ted_1'), {
        approval: 'pending',
        requestedBy: 'bm',
      }),
    );
  });

  test('cannot approve, reject or undo an approval', async () => {
    await seed({ 'bids/c1_ted_1': bid({ approval: 'pending' }) });
    const db = manager();
    await assertFails(
      updateDoc(doc(db, 'bids/c1_ted_1'), { approval: 'approved' }),
    );
    await assertFails(
      updateDoc(doc(db, 'bids/c1_ted_1'), { approval: 'rejected' }),
    );
    await seed({ 'bids/c1_ted_1': approvedBid() });
    // A stale "ask" after the owner approved.
    await assertFails(
      updateDoc(doc(db, 'bids/c1_ted_1'), {
        approval: 'pending',
        requestedBy: 'bm',
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'bids/c1_ted_1'), {
        stage: 'watching',
        approval: 'pending',
      }),
    );
  });

  test('cannot leave Watching without approval', async () => {
    await seed({ 'bids/c1_ted_1': bid({ approval: 'pending' }) });
    await assertFails(
      updateDoc(doc(manager(), 'bids/c1_ted_1'), { stage: 'preparing' }),
    );
  });

  test('cannot edit owner-only fields', async () => {
    await seed({ 'bids/c1_ted_1': approvedBid() });
    const db = manager();
    for (const change of [
      { approvalNote: 'Approved by me' },
      { verdict: 'NO_BID' },
      { fitScore: 10 },
      { title: 'x' },
      { ownerUid: 'bm2' },
      { companyId: 'c2' },
    ]) {
      await assertFails(updateDoc(doc(db, 'bids/c1_ted_1'), change));
    }
  });

  test('moves an approved bid forward and records loss reasons', async () => {
    await seed({ 'bids/c1_ted_1': approvedBid() });
    const db = manager();
    await assertFails(
      updateDoc(doc(db, 'bids/c1_ted_1'), { stage: 'won' }),
      'cannot skip Submitted',
    );
    await assertSucceeds(
      updateDoc(doc(db, 'bids/c1_ted_1'), { stage: 'submitted' }),
    );
    await assertFails(
      updateDoc(doc(db, 'bids/c1_ted_1'), { lossReasons: ['Other'] }),
      'reasons only when lost',
    );
    await assertSucceeds(
      updateDoc(doc(db, 'bids/c1_ted_1'), {
        stage: 'lost',
        lossReasons: ['Price too high'],
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'bids/c1_ted_1'), { stage: 'won' }),
      'no move after the outcome',
    );
  });

  test('works the checklist', async () => {
    await seed({ 'bids/c1_ted_1': approvedBid() });
    await assertSucceeds(
      updateDoc(doc(manager(), 'bids/c1_ted_1'), {
        tasks: [...checklist, { id: 't9', title: 'New', done: false }],
      }),
    );
  });

  test('cannot delete a bid', async () => {
    await seed({ 'bids/c1_ted_1': bid() });
    await assertFails(deleteDoc(doc(manager(), 'bids/c1_ted_1')));
  });
});

describe('bids: field-level writes from 2 phones', () => {
  test('ticks go to taskDone, so 2 ticks on different tasks both land', async () => {
    await seed({ 'bids/c1_ted_1': approvedBid() });
    await assertSucceeds(
      updateDoc(doc(manager(), 'bids/c1_ted_1'), 'taskDone.t0', true),
    );
    await assertSucceeds(
      updateDoc(doc(owner(), 'bids/c1_ted_1'), 'taskDone.t1', true),
    );
    const ticks = await read('bids/c1_ted_1', (d) => d.taskDone);
    if (!ticks.t0 || !ticks.t1) {
      throw new Error(`a tick was lost: ${JSON.stringify(ticks)}`);
    }
  });

  test('a bid manager adds tasks but never removes them', async () => {
    await seed({ 'bids/c1_ted_1': approvedBid() });
    const db = manager();
    await assertSucceeds(
      updateDoc(doc(db, 'bids/c1_ted_1'), {
        tasks: arrayUnion({ id: 't9', title: 'New', assigneeUid: null, done: false }),
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'bids/c1_ted_1'), { tasks: checklist.slice(1) }),
    );
  });

  test('a fresh bid written over an existing one is refused', async () => {
    await seed({ 'bids/c1_ted_1': approvedBid() });
    const fresh = bid({ createdAt: '2026-11-27T00:00:00.000Z' });
    await assertFails(setDoc(doc(owner(), 'bids/c1_ted_1'), fresh));
    await assertFails(setDoc(doc(manager(), 'bids/c1_ted_1'), fresh));
  });

  test('a removed bid reads as missing instead of failing', async () => {
    const snap = await assertSucceeds(getDoc(doc(manager(), 'bids/c1_ted_9')));
    if (snap.exists()) throw new Error('should not exist');
  });

  test('the owner decides with a transaction-style update', async () => {
    await seed({ 'bids/c1_ted_1': bid({ approval: 'pending', requestedBy: 'bm' }) });
    const db = owner();
    const batch = writeBatch(db);
    batch.update(doc(db, 'bids/c1_ted_1'), {
      approval: 'approved',
      approvalNote: 'Go',
      stage: 'preparing',
      tasks: arrayUnion(...checklist),
    });
    batch.set(doc(db, 'approvals/c1_ted_1_2'), {
      id: 'c1_ted_1_2',
      bidId: 'c1_ted_1',
      companyId: 'c1',
      decision: 'approved',
      by: 'owner',
      note: 'Go',
      at: NOW,
    });
    await assertSucceeds(batch.commit());
  });
});

describe('bids: owner', () => {
  test('approves with an approval record in one batch', async () => {
    await seed({ 'bids/c1_ted_1': bid({ approval: 'pending' }) });
    const db = owner();
    const batch = writeBatch(db);
    batch.set(doc(db, 'approvals/c1_ted_1_1'), {
      id: 'c1_ted_1_1',
      bidId: 'c1_ted_1',
      companyId: 'c1',
      decision: 'approved',
      by: 'owner',
      note: 'Go',
      at: NOW,
    });
    batch.update(doc(db, 'bids/c1_ted_1'), {
      approval: 'approved',
      approvalNote: 'Go',
      stage: 'preparing',
      tasks: checklist,
    });
    await assertSucceeds(batch.commit());
  });

  test('a bid manager cannot write an approval record', async () => {
    await assertFails(
      setDoc(doc(manager(), 'approvals/x'), {
        id: 'x',
        bidId: 'c1_ted_1',
        companyId: 'c1',
        decision: 'approved',
        by: 'bm',
        note: '',
        at: NOW,
      }),
    );
  });

  test('removes a bid', async () => {
    await seed({ 'bids/c1_ted_1': bid() });
    await assertSucceeds(deleteDoc(doc(owner(), 'bids/c1_ted_1')));
  });
});

describe('bids: queries', () => {
  test('members list their company bids', async () => {
    await seed({ 'bids/c1_ted_1': bid() });
    await assertSucceeds(
      getDocs(
        query(collection(manager(), 'bids'), where('companyId', '==', 'c1')),
      ),
    );
    await assertFails(
      getDocs(
        query(collection(stranger(), 'bids'), where('companyId', '==', 'c1')),
      ),
    );
  });
});

const inviteFor = (email, overrides = {}) => ({
  email,
  companyId: 'c1',
  companyName: 'Firm',
  invitedBy: 'owner',
  role: 'bid_manager',
  createdAt: NOW,
  ...overrides,
});

describe('invites: the invitee', () => {
  test('listens to their own invite before it exists', async () => {
    const snap = await assertSucceeds(
      getDoc(doc(as('newbie'), 'invites/newbie@firm.test')),
    );
    if (snap.exists()) throw new Error('should not exist yet');
  });

  test('cannot read an invite for another address', async () => {
    await seed({ 'invites/bm2@firm.test': inviteFor('bm2@firm.test') });
    await assertFails(getDoc(doc(stranger(), 'invites/bm2@firm.test')));
  });

  test('declines by deleting it', async () => {
    await seed({ 'invites/newbie@firm.test': inviteFor('newbie@firm.test') });
    await assertSucceeds(
      deleteDoc(doc(as('newbie'), 'invites/newbie@firm.test')),
    );
  });
});

describe('invites: the owner', () => {
  test('sends an invite and sends it again', async () => {
    const db = owner();
    const ref = doc(db, 'invites/new@firm.test');
    await assertSucceeds(setDoc(ref, inviteFor('new@firm.test')));
    await assertSucceeds(
      setDoc(ref, inviteFor('new@firm.test', { createdAt: '2026-11-27T00:00:00.000Z' })),
    );
  });

  test("cannot take over another company's invite", async () => {
    await seed({
      'invites/new@firm.test': inviteFor('new@firm.test', {
        companyId: 'c2',
        companyName: 'Other',
        invitedBy: 'rival',
      }),
    });
    await assertFails(
      setDoc(doc(owner(), 'invites/new@firm.test'), inviteFor('new@firm.test')),
    );
  });

  test('a bid manager cannot invite', async () => {
    await assertFails(
      setDoc(
        doc(manager(), 'invites/new@firm.test'),
        inviteFor('new@firm.test', { invitedBy: 'bm' }),
      ),
    );
  });
});

/** A tender exactly as Tender.toJson() writes it. */
function tender(overrides = {}) {
  return {
    source: 'ted',
    sourceId: '612345-2026',
    title: 'Hospital system',
    buyer: 'Ministry',
    country: 'LKA',
    cpvCodes: ['72200000'],
    deadline: '2026-12-20T00:00:00.000Z',
    estimatedValue: null,
    currency: null,
    minTurnover: null,
    noticeText: 'Notice text',
    textHash: 'abcdef0123456789abcdef',
    url: null,
    documentUrls: [],
    fetchedAt: NOW,
    ...overrides,
  };
}

const scanned = (overrides = {}) =>
  tender({
    source: 'scan',
    sourceId: 'abcdef0123456789',
    textHash: 'abcdef0123456789ffff',
    ...overrides,
  });

describe('tenders', () => {
  test('the sync saves and refreshes a tender on any phone', async () => {
    await assertSucceeds(
      setDoc(doc(manager(), 'tenders/ted_612345-2026'), tender()),
    );
    await assertSucceeds(
      setDoc(
        doc(as('rival'), 'tenders/ted_612345-2026'),
        tender({ fetchedAt: '2026-11-27T00:00:00.000Z', deadline: null }),
      ),
    );
    await assertSucceeds(
      setDoc(
        doc(owner(), 'tenders/worldbank_OP000123'),
        tender({ source: 'worldbank', sourceId: 'OP000123', cpvCodes: [] }),
      ),
    );
  });

  test('refuses a wrong ID, unknown fields or a missing field', async () => {
    const db = manager();
    await assertFails(setDoc(doc(db, 'tenders/ted_other'), tender()));
    await assertFails(
      setDoc(doc(db, 'tenders/ted_612345-2026'), tender({ hacked: true })),
    );
    const noText = tender();
    delete noText.noticeText;
    await assertFails(setDoc(doc(db, 'tenders/ted_612345-2026'), noText));
    await assertFails(
      setDoc(doc(db, 'tenders/x_612345-2026'), tender({ source: 'x' })),
    );
  });

  test('a scanned notice keeps its text', async () => {
    const db = manager();
    await assertSucceeds(
      setDoc(doc(db, 'tenders/scan_abcdef0123456789'), scanned()),
    );
    await assertSucceeds(
      setDoc(
        doc(owner(), 'tenders/scan_abcdef0123456789'),
        scanned({ buyer: 'Confirmed buyer' }),
      ),
    );
    await assertFails(
      setDoc(
        doc(owner(), 'tenders/scan_abcdef0123456789'),
        scanned({ noticeText: 'Rewritten' }),
      ),
    );
    await assertFails(
      setDoc(
        doc(db, 'tenders/scan_0000000000000000'),
        scanned({ sourceId: '0000000000000000' }),
      ),
    );
  });

  test('signed-out users cannot write', async () => {
    await assertFails(
      setDoc(
        doc(env.unauthenticatedContext().firestore(), 'tenders/ted_612345-2026'),
        tender(),
      ),
    );
  });
});

describe('verdicts', () => {
  test("members read their company's verdicts on a tender", async () => {
    await seed({
      'verdicts/v1': { id: 'v1', companyId: 'c1', tenderId: 'ted_1', at: NOW },
    });
    await assertSucceeds(
      getDocs(
        query(
          collection(owner(), 'verdicts'),
          where('companyId', '==', 'c1'),
          where('tenderId', '==', 'ted_1'),
        ),
      ),
    );
    await assertFails(
      getDocs(
        query(
          collection(as('rival'), 'verdicts'),
          where('companyId', '==', 'c1'),
          where('tenderId', '==', 'ted_1'),
        ),
      ),
    );
  });
});

/** The acceptInvite batch, as CompanyRepository.acceptInvite writes it. */
function acceptBatch(db, uid, companyId = 'c1', role = 'bid_manager') {
  const email = `${uid}@firm.test`;
  const batch = writeBatch(db);
  batch.update(doc(db, `companies/${companyId}`), {
    [`members.${uid}`]: role,
    [`memberEmails.${uid}`]: email,
  });
  batch.set(doc(db, `users/${uid}`), { companyId, email });
  batch.delete(doc(db, `invites/${email}`));
  return batch;
}

describe('invites: verified email', () => {
  beforeEach(() =>
    seed({ 'invites/newbie@firm.test': inviteFor('newbie@firm.test') }),
  );

  test('a verified invitee joins as bid manager', async () => {
    await assertSucceeds(acceptBatch(as('newbie'), 'newbie').commit());
  });

  test('an unverified invitee sees the invite but cannot use it', async () => {
    const db = as('newbie', { email_verified: false });
    await assertSucceeds(getDoc(doc(db, 'invites/newbie@firm.test')));
    await assertFails(acceptBatch(db, 'newbie').commit());
    await assertFails(deleteDoc(doc(db, 'invites/newbie@firm.test')));
  });

  test('a token without the claim counts as unverified', async () => {
    const db = env
      .authenticatedContext('newbie', { email: 'newbie@firm.test' })
      .firestore();
    await assertFails(acceptBatch(db, 'newbie').commit());
  });

  test('the invitee cannot join as owner or join another company', async () => {
    await assertFails(acceptBatch(as('newbie'), 'newbie', 'c1', 'owner').commit());
    await assertFails(acceptBatch(as('newbie'), 'newbie', 'c2').commit());
  });
});
