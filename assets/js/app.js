import "phoenix_html"
import {Socket, Presence} from "phoenix"
import {Sketchpad, sanitize} from "./sketchpad"

const App = {
  init(userId, token) {
    this.userId = userId;
    this.initPad("sketchpad")
    this.initSocket(token)
    this.initChat(token)
    document.getElementById('export-button').addEventListener('click', () => 
      window.open(this.pad.getImageURL())
    )
  },

  initChat() {
    this.messages = document.getElementById('messages')
    this.msgInput = document.getElementById('message-input')

    let onOk = () => {
      this.msgInput.value = ""
      this.msgInput.disabled = false
    }

    let onError = () => {
      this.msgInput.disabled = false
    }

    this.msgInput.addEventListener("keypress", e => {
      if (e.keyCode !== 13) return;

      let body = this.msgInput.value;
      this.msgInput.disabled = true;
      this.padChannel.push("new_msg", { body })
        .receive("ok", onOk)
        .receive("error", onError)
        .receive("timeout", onError)
    })

    this.padChannel.on("new_msg", (data) => {
      console.log( data )
      const { user_id, body } = data;
      this.messages.innerHTML += 
        `<br/><b>${sanitize(user_id)}:</b> ${sanitize(body)}`
      
      this.messages.scrollTop = this.messages.scrollHeight
    })
  },

  initPad(elId) {
    this.el = document.getElementById(elId)
    this.pad = new Sketchpad(this.el, this.userId)
    this.clearButton = document.getElementById('clear-button')
    this.exportButton = document.getElementById('export-button')
    this.userContainer = document.getElementById('users');

    this.clearButton.onmouseup = () => {
      this.pad.clear();
      this.padChannel.push("clear");
    }

    this.pad.on("stroke", data => this.padChannel.push("stroke", data))
  },

  initSocket(token) {
    this.presences = {}
    this.socket = new Socket("/socket", { params: { token } })
    this.socket.connect()
    this.padChannel = this.socket.channel("pad:lobby", { user_agent: navigator.userAgent, enteredAt: new Date().toDateString() })

    const onJoin = (user_id, current, newPresence) => {
      if (!current) console.log(`${user_id} has joined`)
      else console.log(`${user_id} has opened a new tab`)
    }

    const onLeave = (user_id, current, leftPresence) => {
      if (current.metas.length === 0) {
        console.log(`${user_id} has left`)
      } else {
        console.log(`${user_id} has closed a tab`)
      }
    }

    this.padChannel.on("presence_state", state => {
      this.presences = Presence.syncState(this.presences, state, onJoin, onLeave)
      this.renderUsers(this.users, this.presences)
    })

    this.padChannel.on("presence_diff", diff => {
      this.presences = Presence.syncDiff(this.presences, diff, onJoin, onLeave)
      this.renderUsers(this.users, this.presences)
    })

    this.padChannel.join()
      .receive("ok", res => console.log(res))
      .receive("error", res => console.log("error", res))

    this.padChannel.on("stroke", data => {
      this.pad.putStroke(data.user_id, data.stroke, { color: "#000000" })
    })

    this.padChannel.on("clear", () => {
      this.pad.clear();
    })

    this.padChannel.on("generate_png", () => {
      this.padChannel.push("png", { img: this.pad.getImageURL() })
    })
  },

  renderUsers(a, presences) {
    const users = Presence.list(presences, (user_id, { metas: [first, ...rest]}) => {
      console.log(first, rest);

      return {
        id: user_id,
        count: rest.length + 1,
        meta: first.meta
      };
    })

    console.log(users)

    this.userContainer.innerHTML = users.map(u => (
      `<div>${u.id} (${u.count})</div>`
    ))
  }
}

App.init(window.userId, window.userToken)
