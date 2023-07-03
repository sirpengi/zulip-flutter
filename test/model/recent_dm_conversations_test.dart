import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';
import 'package:zulip/api/model/events.dart';
import 'package:zulip/api/model/initial_snapshot.dart';
import 'package:zulip/model/narrow.dart';
import 'package:zulip/model/recent_dm_conversations.dart';

import '../example_data.dart' as eg;
import 'recent_dm_conversations_checks.dart';

void main() {
  group('RecentDmConversationsView', () {
    /// Get a [DmNarrow] from a list of recipient IDs excluding self.
    DmNarrow key(userIds) {
      return DmNarrow(
        allRecipientIds: [eg.selfUser.userId, ...userIds]..sort(),
        selfUserId: eg.selfUser.userId,
      );
    }

    test('construct from initial data', () {
      check(RecentDmConversationsView(selfUserId: eg.selfUser.userId,
        initial: []))
          ..map.isEmpty()
          ..sorted.isEmpty();

      check(RecentDmConversationsView(selfUserId: eg.selfUser.userId,
        initial: [
          RecentDmConversation(userIds: [],     maxMessageId: 200),
          RecentDmConversation(userIds: [1],    maxMessageId: 100),
          RecentDmConversation(userIds: [2, 1], maxMessageId: 300), // userIds out of order
        ]))
          ..map.deepEquals({
            key([1, 2]): 300,
            key([]):     200,
            key([1]):    100,
          })
          ..sorted.deepEquals([key([1, 2]), key([]), key([1])]);
    });

    group('message event (new message)', () {
      setupView() {
        return RecentDmConversationsView(selfUserId: eg.selfUser.userId,
          initial: [
            RecentDmConversation(userIds: [1],    maxMessageId: 200),
            RecentDmConversation(userIds: [1, 2], maxMessageId: 100),
          ]);
      }

      test('(check base state)', () {
        // This is here mostly for checked documentation of what
        // setupView returns, to help in reading the other test cases.
        check(setupView())
          ..map.deepEquals({
            key([1]):    200,
            key([1, 2]): 100,
          })
          ..sorted.deepEquals([key([1]), key([1, 2])]);
      });

      test('stream message -> do nothing', () {
        bool listenersNotified = false;
        final expected = setupView();
        check(setupView()
          ..addListener(() { listenersNotified = true; })
          ..handleMessageEvent(MessageEvent(id: 1, message: eg.streamMessage()))
        ) ..map.deepEquals(expected.map)
          ..sorted.deepEquals(expected.sorted);
        check(listenersNotified).isFalse();
      });

      test('new conversation, newest message', () {
        bool listenersNotified = false;
        final message = eg.dmMessage(id: 300, from: eg.selfUser, to: [eg.user(userId: 2)]);
        check(setupView()
          ..addListener(() { listenersNotified = true; })
          ..handleMessageEvent(MessageEvent(id: 1, message: message))
        ) ..map.deepEquals({
            key([2]):    300,
            key([1]):    200,
            key([1, 2]): 100,
          })
          ..sorted.deepEquals([key([2]), key([1]), key([1, 2])]);
        check(listenersNotified).isTrue();
      });

      test('new conversation, not newest message', () {
        bool listenersNotified = false;
        final message = eg.dmMessage(id: 150, from: eg.selfUser, to: [eg.user(userId: 2)]);
        check(setupView()
          ..addListener(() { listenersNotified = true; })
          ..handleMessageEvent(MessageEvent(id: 1, message: message))
        ) ..map.deepEquals({
            key([1]):    200,
            key([2]):    150,
            key([1, 2]): 100,
          })
          ..sorted.deepEquals([key([1]), key([2]), key([1, 2])]);
        check(listenersNotified).isTrue();
      });

      test('existing conversation, newest message', () {
        bool listenersNotified = false;
        final message = eg.dmMessage(id: 300, from: eg.selfUser,
          to: [eg.user(userId: 1), eg.user(userId: 2)]);
        check(setupView()
          ..addListener(() { listenersNotified = true; })
          ..handleMessageEvent(MessageEvent(id: 1, message: message))
        ) ..map.deepEquals({
            key([1, 2]): 300,
            key([1]):    200,
          })
          ..sorted.deepEquals([key([1, 2]), key([1])]);
        check(listenersNotified).isTrue();
      });

      test('existing newest conversation, newest message', () {
        bool listenersNotified = false;
        final message = eg.dmMessage(id: 300, from: eg.selfUser, to: [eg.user(userId: 1)]);
        check(setupView()
          ..addListener(() { listenersNotified = true; })
          ..handleMessageEvent(MessageEvent(id: 1, message: message))
        ) ..map.deepEquals({
            key([1]):    300,
            key([1, 2]): 100,
          })
          ..sorted.deepEquals([key([1]), key([1, 2])]);
        check(listenersNotified).isTrue();
      });

      test('existing conversation, not newest in conversation', () {
        final message = eg.dmMessage(id: 99, from: eg.selfUser,
          to: [eg.user(userId: 1), eg.user(userId: 2)]);
        final expected = setupView();
        check(setupView()
          ..handleMessageEvent(MessageEvent(id: 1, message: message))
        ) ..map.deepEquals(expected.map)
          ..sorted.deepEquals(expected.sorted);
      });
    });
  });
}