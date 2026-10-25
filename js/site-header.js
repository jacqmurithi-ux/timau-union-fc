/* Shared public-site header: accessible mobile menu and page search. */
(()=>{
  "use strict";
  const init=()=>{
    const menuToggle=document.getElementById("menu-toggle");
    const nav=document.getElementById("primary-nav");
    if(menuToggle&&nav&&menuToggle.dataset.navigationReady!=="true"){
      menuToggle.dataset.navigationReady="true";
      let menuOpen=false;
      let closeButton=nav.querySelector(".primary-nav-close");
      if(!closeButton){
        closeButton=document.createElement("button");closeButton.type="button";closeButton.className="primary-nav-close";
        closeButton.setAttribute("aria-label","Close navigation menu");closeButton.textContent="× Close menu";nav.prepend(closeButton);
      }
      const icon=menuToggle.querySelector(".menu-icon");
      const setMenuState=(open,returnFocus=false)=>{
        menuOpen=open;nav.classList.toggle("is-open",open);
        menuToggle.setAttribute("aria-expanded",String(open));
        menuToggle.setAttribute("aria-label",open?"Close navigation menu":"Open navigation menu");
        if(icon){icon.textContent=open?"×":"☰";icon.setAttribute("aria-hidden","true");}
        document.documentElement.classList.toggle("navigation-open",open);
        document.body.classList.toggle("navigation-open",open);
        if(returnFocus)menuToggle.focus();
      };
      setMenuState(false);
      menuToggle.addEventListener("click",event=>{event.preventDefault();setMenuState(!menuOpen);});
      closeButton.addEventListener("click",()=>setMenuState(false));
      nav.querySelectorAll("a").forEach(link=>link.addEventListener("click",()=>setMenuState(false)));
      document.addEventListener("pointerdown",event=>{
        if(menuOpen&&!nav.contains(event.target)&&!menuToggle.contains(event.target))setMenuState(false);
      });
      document.addEventListener("keydown",event=>{if(event.key==="Escape"&&menuOpen)setMenuState(false,true);});
      document.addEventListener("touchmove",event=>{
        if(menuOpen&&!nav.contains(event.target)&&!menuToggle.contains(event.target))event.preventDefault();
      },{passive:false});
      const desktop=window.matchMedia("(min-width: 960px)");
      const layout=event=>{if(event.matches&&menuOpen)setMenuState(false);};
      if(desktop.addEventListener)desktop.addEventListener("change",layout);else desktop.addListener(layout);
    }
    const toggle=document.getElementById("site-search-toggle");
    const panel=document.getElementById("site-search-panel");
    const form=document.getElementById("site-search-form");
    const input=document.getElementById("site-search-input");
    const results=document.getElementById("site-search-results");
    if(toggle&&panel&&form&&input&&results&&toggle.dataset.searchReady!=="true"){
      toggle.dataset.searchReady="true";
      const open=state=>{panel.hidden=!state;toggle.setAttribute("aria-expanded",String(state));if(state)input.focus();};
      toggle.addEventListener("click",()=>open(panel.hidden));
      document.addEventListener("keydown",event=>{if(event.key==="Escape"&&!panel.hidden){open(false);toggle.focus();}});
      form.addEventListener("submit",event=>{
        event.preventDefault();results.replaceChildren();
        const query=input.value.trim().toLocaleLowerCase();
        if(query.length<2){const p=document.createElement("p");p.textContent="Enter at least two characters.";results.append(p);return;}
        const matches=[];
        document.querySelectorAll("main h1,main h2,main h3,main article,main .match-feature").forEach(node=>{
          if(!node.textContent.toLocaleLowerCase().includes(query))return;
          const heading=node.matches("h1,h2,h3")?node:node.querySelector("h1,h2,h3");
          const label=(heading?heading.textContent:node.textContent).trim().replace(/\s+/g," ").slice(0,130);
          if(!label)return;
          const section=node.closest("section");
          let href=section&&section.id?"#"+section.id:"#main";
          if(node.closest(".partner-card"))href="/partnership.html";
          matches.push({label,href});
        });
        const seen=new Set();
        matches.forEach(item=>{
          const key=item.label+"|"+item.href;if(seen.has(key))return;seen.add(key);
          const link=document.createElement("a");link.textContent=item.label;link.href=item.href;
          link.addEventListener("click",()=>open(false));results.append(link);
        });
        if(!seen.size){const p=document.createElement("p");p.textContent="No public results found.";results.append(p);}
      });
    }
  };
  if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",init,{once:true});else init();
})();