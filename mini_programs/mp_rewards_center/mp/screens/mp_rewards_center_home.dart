import 'package:mini_program_ui/mini_program_ui.dart';

MpNode buildMpRewardsCenterHome() {
  return Mp.column(
    children: <MpNode>[
      Mp.heading('Mp Rewards Center'),
      Mp.text('Auth, backend, and paged list coverage from Mp JSON.'),
      Mp.sizedBox(height: 16),
      Mp.authBuilder(
        loading: Mp.text('Checking reward session...'),
        signedOut: Mp.card(
          child: Mp.column(
            children: <MpNode>[
              Mp.heading('Publisher account'),
              Mp.text('Sign in to unlock Mp rewards.'),
              Mp.primaryButton(
                label: 'Sign in with email',
                action: Mp.auth.showEmailAuth(),
              ),
            ],
          ),
        ),
        signedIn: Mp.card(
          child: Mp.column(
            children: <MpNode>[
              Mp.text('Signed in as {{auth.user.email}}'),
              Mp.secondaryButton(label: 'Sign out', action: Mp.auth.signOut()),
            ],
          ),
        ),
        error: Mp.text('{{auth.message}}'),
      ),
      Mp.sizedBox(height: 16),
      Mp.backendBuilder(
        requestId: 'home',
        endpoint: 'home/bootstrap',
        cacheTtlSeconds: 30,
        loading: Mp.text('Loading reward summary...'),
        error: Mp.text('{{backend.home.message}}'),
        empty: Mp.text('No reward summary is available.'),
        child: Mp.card(
          child: Mp.column(
            children: <MpNode>[
              Mp.heading('{{backend.home.data.title}}'),
              Mp.text('{{backend.home.data.message}}'),
              Mp.text('Member: {{backend.home.data.user.name}}'),
            ],
          ),
        ),
      ),
      Mp.sizedBox(height: 16),
      Mp.lazy.chunk(
        id: 'rewards_chunk',
        itemsState: 'rewards.items',
        cursorState: 'rewards.next_cursor',
        hasMoreState: 'rewards.has_more',
        statusState: 'rewards.status',
        cacheKeyPrefix: 'rewards_chunk',
        ttl: const Duration(seconds: 30),
        placeholder: Mp.text('Loading rewards...'),
        loadingMore: Mp.text('Loading more rewards...'),
        error: Mp.text('Rewards failed to load.'),
        empty: Mp.text('No Mp rewards yet.'),
        end: Mp.text('No more Mp rewards.'),
        itemTemplate: Mp.card(
          child: Mp.column(
            children: <MpNode>[
              Mp.heading('{{item.title}}'),
              Mp.text('{{item.description}}'),
              Mp.text('Sort index: {{item.sortIndex}}'),
            ],
          ),
        ),
        initialActions: <MpAction>[
          Mp.backend.loadMore(
            requestId: 'rewards',
            endpoint: 'coupons/page',
            limit: 1,
            cacheTtlSeconds: 30,
          ),
        ],
        loadMoreActions: <MpAction>[
          Mp.backend.loadMore(
            requestId: 'rewards',
            endpoint: 'coupons/page',
            limit: 1,
            cacheTtlSeconds: 30,
          ),
        ],
        loadMore: Mp.secondaryButton(
          label: 'Load more rewards',
          action: Mp.lazy.loadMore(id: 'rewards_chunk'),
        ),
      ),
    ],
  );
}
