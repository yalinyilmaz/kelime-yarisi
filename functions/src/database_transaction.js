// Conditional RTDB transactions must load remote state before aborting on null.
export async function transaction(ref,update) {
  let listener;
  await new Promise((resolve,reject)=>{listener=()=>resolve();ref.on('value',listener,reject);});
  try {return await ref.transaction(update);}
  finally {ref.off('value',listener);}
}
