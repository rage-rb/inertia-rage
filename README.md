<p align="center"><img height="200" alt="logo" src="https://github.com/user-attachments/assets/d010d189-5f54-43cc-a07a-248109248b59" /></p>

# Inertia Rage

The official [Inertia.js](https://inertiajs.com) adapter for the [Rage](https://github.com/rage-rb/rage) framework.

This gem handles Inertia page responses, provides flexible prop types, and integrates seamlessly with Vite.

## Usage

Create a Rage app and add the gem:

```
rage new my-app -d postgresql
bundle add inertia-rage
```

Create a frontend project in any directory within your project's root or `app` folder:

```
npm create vite@latest app/frontend
```

Install the required packages and initialize your Inertia app. Refer to the Inertia documentation for [client-side setup](https://inertiajs.com/docs/v3/installation/client-side-setup).

<details>

<summary>If you are using React</summary>

Vite's React template uses `root` as the container element id, but Inertia expects `app`. Update `index.html` accordingly:

```diff
<body>
-  <div id="root"></div>
+  <div id="app"></div>
  <script type="module" src="/src/main.ts"></script>
</body>
```

</details>

Start the app:

```
rage s
```

Rage automatically starts the Vite dev server in development and pre-builds assets in other environments. In most cases, `rage s` is all you need to run your app.

## Rendering

Use `render inertia:` to render Inertia responses in your controller actions:

```ruby
class PostsController < ApplicationController
  def index
    render inertia: "Posts/Index", props: { posts: current_user.posts }
  end
end
```

Rage can also infer the component name from the current controller and action. The following will render the `Posts/Index` component:

```ruby
class PostsController < ApplicationController
  def index
    render inertia: { posts: current_user.posts }
  end
end
```

Redirects are supported via `redirect_to`, `redirect_back`, and `redirect_back_or_to`:

```ruby
class PostsController < ApplicationController
  def create
    Post.create!(post_params)
    redirect_back fallback_location: "/"
  end
end
```

## Props

Inertia Rage supports several prop types to optimize data loading and improve performance.

### Lazy Props

Define lazy props using procs:

```ruby
render inertia: {
  user:,
  posts: -> { user.posts }
}
```

Lazy props are evaluated on the initial page load just like regular props. The difference emerges during partial reloads: lazy props are only evaluated when explicitly requested. For example, if a partial reload requests only `user`, the `posts` query is skipped entirely.

### Deferred Props

Deferred props are excluded from the initial page load and fetched automatically in a subsequent request:

```ruby
render inertia: {
  user:,
  comments: Inertia.deferred { user.build_comments_tree }
}
```

Use deferred props for expensive operations that would otherwise slow down the initial page load.

### Optional Props

Optional props are never evaluated during the initial page load. The frontend must explicitly request them:

```ruby
render inertia: {
  user:,
  last_posted_at: Inertia.optional { user.posts.last.created_at }
}
```

### Once Props

Once props are cached by the frontend after their first evaluation. On subsequent requests, the cached value is used and the prop is not re-evaluated. Since Inertia resets the cache for once props that are absent from the page, you'll typically want to use them inside `inertia_share` blocks:

```ruby
class ApplicationController < RageController::API
  inertia_share do
    { permissions: Inertia.once { current_user.permissions } }
  end
end
```

## Shared Data

Use `inertia_share` to share data across all Inertia responses:

```ruby
class ApplicationController < RageController::API
  inertia_share do
    { has_new_notifications: current_user.notifications.unread.exists? }
  end
end
```

`inertia_share` accepts the same arguments as [`before_action`](https://api.rage-rb.dev/RageController/API#before_action-class_method):

```ruby
class DashboardsController < ApplicationController
  inertia_share if: :user_signed_in?, except: :destroy do
    { all_dashboards: Dashboard.where.not(user: current_user) }
  end
end
```

## Testing with RSpec

The gem provides an [`inertia`](https://inertia-api.rage-rb.dev/Inertia/RSpec/TestResponse) helper for testing Inertia responses. Require `inertia/rspec` in your request specs to access it:

```ruby
require "inertia/rspec"

RSpec.describe UsersController, type: :request do
  it "renders user posts" do
    get "posts"

    expect(inertia.component).to eq("Posts/Index")
    expect(inertia.props).to have_key(:posts)
  end
end
```

Partial reloading is supported via the [`inertia` option](https://inertia-api.rage-rb.dev/Inertia/RSpec/RequestHelpers.html) on the `get` method:

```ruby
require "inertia/rspec"

RSpec.describe UsersController, type: :request do
  it "renders post comments" do
    get "posts/1", inertia: { only: :comments }

    expect(inertia.props.keys).to eq(:comments)
  end
end
```

## Configuration

Use `Inertia.configure` to customize the default behavior:

```ruby
Inertia.configure do |config|
  config.build_on_start = false
  config.dev_server.port = 5000
end
```

See the [API documentation](https://inertia-api.rage-rb.dev/Inertia/Configuration.html) for the complete list of configuration options.

## Learn More

- [Props API Reference](https://inertia-api.rage-rb.dev/Inertia)
- [Controller API Reference](https://inertia-api.rage-rb.dev/Inertia/ControllerHelpers.html)
- [Configuration API Reference](https://inertia-api.rage-rb.dev/Inertia/Configuration.html)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rage-rb/inertia-rage. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/rage-rb/inertia-rage/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Inertia::Rage project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/rage-rb/inertia-rage/blob/master/CODE_OF_CONDUCT.md).
