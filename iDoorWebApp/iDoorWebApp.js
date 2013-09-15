Messages = new Meteor.Collection("messages");

if (Meteor.isClient) {
  Router.map(function() {
    this.route("home", {path: '/'});
    this.route("message", {
      path: "/messages/:_id",
      data: function() {return Messages.findOne(this.params._id);}
    });
    this.route("new_message",{
      path: "/new_message/:message",
      data: function() {
        newMessageID = Messages.insert({content: this.params.message});
        Meteor.call("send_email", Router.url("message", {_id: newMessageID}));
        Router.go("message", {_id: newMessageID});
      }
    });
  });

  Template.home.greeting = function () {
    return "Welcome to iDoorWebApp.";
  };

  Template.home.events({
    'click input' : function () {
      // template data, if any, is available in 'this'
    }
  });

  Template.message.message = function(){
    return this.content;
  };
}

if (Meteor.isServer) {
  Meteor.startup(function () {
    // code to run on server at startup
    Meteor.methods({
      send_email: function(content) {
        console.log(content);
        return Email.send({
          from: "door@idoor.meteor.com",
          to: "drew.a.gross@gmail.com",
          subject: "New message from iDoor!",
          text: content
        });
      }
    });
  });
}
