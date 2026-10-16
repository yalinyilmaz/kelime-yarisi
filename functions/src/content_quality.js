import {LENGTHS, isPublished, validatePool} from './content.js';
import {capacityReport, selectSet} from './set_selector.js';

export function qualityReport(pool, {trials=10, days=90, gamesPerDay=3}={}) {
  if(!Number.isInteger(trials)||trials<1||trials>100||!Number.isInteger(days)||days<1||days>1000||!Number.isInteger(gamesPerDay)||gamesPerDay<1||gamesPerDay>100)throw new Error('Invalid quality-report bounds.');
  const published=pool.filter(q=>isPublished(q));
  const capacity=capacityReport(published);
  const simulations=[];
  for(let trial=0;trial<trials;trial++) {
    let state=trial+1;
    const random=()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state/4294967296;};
    const seenAnswerIds=[],seenQuestionIds=[];
    let games=0,stopReason='upper-bound-reached';
    while(games<capacity.upperBoundSets) {
      try {
        const selected=selectSet(published,[{seenAnswerIds,seenQuestionIds}],{random});
        seenAnswerIds.push(...selected.questions.map(q=>q.answerId));seenQuestionIds.push(...selected.questions.map(q=>q.id));games++;
      } catch(error) {if(!error.code)throw error;stopReason=error.code;break;}
    }
    simulations.push({seed:trial+1,games,stopReason});
  }
  return {records:pool.length, publishedQuestions:published.length, distinctPublishedAnswers:new Set(published.map(q=>q.answerId)).size,
    automaticErrors:validatePool(pool), aiSelfReviewed:published.filter(q=>q.review.kind==='ai-self-review').length,
    topics:Object.fromEntries([...new Set(published.map(q=>q.topic))].sort().map(topic=>[topic,published.filter(q=>q.topic===topic).length])),
    difficulties:Object.fromEntries([1,2,3].map(level=>[level,published.filter(q=>q.difficulty===level).length])),
    sourceCoverage:published.filter(q=>q.source.reference&&q.source.meaningEvidence&&q.source.termsReference).length,
    capacity, target:{days,gamesPerDay,answersPerLength:days*gamesPerDay*2,
      deficits:LENGTHS.map(length=>({length,missingAnswers:Math.max(0,days*gamesPerDay*2-capacity.groups.find(g=>g.length===length).publishedAnswers)}))},
    simulatedClassicGames:{minimum:Math.min(...simulations.map(s=>s.games)),maximum:Math.max(...simulations.map(s=>s.games)),trials:simulations},
    note:'Seeded simulations are measurements, not a guarantee for all histories or player groups. AI self-review is not human approval or a correctness guarantee.'};
}
